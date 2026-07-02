// =============================================================
// HELPI - Testes do WebSocket (Socket.io)
// Pilar 1 > Domínio de Radar
//
// Testa: Rádio Privado — notificação vai apenas para o socket
//        do profissional correto, não para todos os logados.
//
// NOTA: Testes de integração — levanta um servidor HTTP real com Socket.io
// =============================================================

const http = require('http');
const { Server } = require('socket.io');
const ioClient = require('socket.io-client');
const app = require('../../src/app');

describe('📡 WebSocket — Rádio Privado', () => {
    let httpServer;
    let io;
    let profissionaisConectados;
    let serverPort;

    beforeAll((done) => {
        // Cria servidor HTTP + Socket.io idêntico ao server.js do Helpi
        httpServer = http.createServer(app);
        io = new Server(httpServer, {
            cors: { origin: '*', methods: ['GET', 'POST'] }
        });

        profissionaisConectados = new Map();

        io.on('connection', (socket) => {
            socket.on('ficar_online', (dados) => {
                profissionaisConectados.set(dados.profissional_id, socket.id);
            });

            socket.on('entrar_sala_cliente', (dados) => {
                if (dados.cliente_id) {
                    socket.join(`cliente:${dados.cliente_id}`);
                }
            });

            socket.on('disconnect', () => {
                for (let [id, socketId] of profissionaisConectados.entries()) {
                    if (socketId === socket.id) {
                        profissionaisConectados.delete(id);
                        break;
                    }
                }
            });
        });

        // Injecta no Express (igual ao server.js real)
        app.set('io', io);
        app.set('profissionaisConectados', profissionaisConectados);

        httpServer.listen(0, () => {
            serverPort = httpServer.address().port;
            done();
        });
    });

    afterAll((done) => {
        io.close();
        httpServer.close(done);
    });

    // ─── HELPER: Conectar um socket de teste ────────────────
    const conectarCliente = (opcoes = {}) => {
        return new Promise((resolve) => {
            const socket = ioClient(`http://localhost:${serverPort}`, {
                transports: ['websocket'],
                forceNew: true,
                ...opcoes
            });
            socket.on('connect', () => resolve(socket));
        });
    };

    // ─── TESTE DO RÁDIO PRIVADO (Pagamento) ─────────────────
    describe('Notificação de Pagamento Confirmado', () => {

        it('deve enviar pagamento_confirmado APENAS para o profissional correto', async () => {
            // 1. Conectar 2 profissionais
            const socketProfA = await conectarCliente();
            const socketProfB = await conectarCliente();

            // 2. Registar como profissionais diferentes
            socketProfA.emit('ficar_online', { profissional_id: 'prof-A' });
            socketProfB.emit('ficar_online', { profissional_id: 'prof-B' });

            // Aguarda o registo
            await new Promise(resolve => setTimeout(resolve, 200));

            // 3. Setup das promessas de escuta
            const promessaA = new Promise((resolve) => {
                socketProfA.on('pagamento_confirmado', (data) => {
                    resolve(data);
                });
            });

            const promessaB = new Promise((resolve, reject) => {
                socketProfB.on('pagamento_confirmado', () => {
                    reject(new Error('Profissional B NÃO deveria ter recebido a notificação!'));
                });
                // Se B não receber nada em 1s, está correto
                setTimeout(() => resolve('nao_recebeu'), 1000);
            });

            // 4. Simular envio de notificação apenas para prof-A
            const socketIdA = profissionaisConectados.get('prof-A');
            expect(socketIdA).toBeDefined();

            io.to(socketIdA).emit('pagamento_confirmado', {
                chamado_id: 'test-chamado-123',
                valor: 90
            });

            // 5. Verificar resultados
            const [resultA, resultB] = await Promise.all([promessaA, promessaB]);

            expect(resultA.chamado_id).toBe('test-chamado-123');
            expect(resultA.valor).toBe(90);
            expect(resultB).toBe('nao_recebeu');

            // Cleanup
            socketProfA.disconnect();
            socketProfB.disconnect();
        }, 10000);
    });

    // ─── TESTE DO NOVO CHAMADO (Broadcast Seletivo) ─────────
    describe('Notificação de Novo Chamado', () => {

        it('deve enviar novo_chamado_emergencia apenas para profissionais específicos', async () => {
            // 1. Conectar 2 profissionais
            const socketProfC = await conectarCliente();
            const socketProfD = await conectarCliente();

            socketProfC.emit('ficar_online', { profissional_id: 'prof-C' });
            socketProfD.emit('ficar_online', { profissional_id: 'prof-D' });

            await new Promise(resolve => setTimeout(resolve, 200));

            // 2. Setup das promessas
            const promessaC = new Promise((resolve) => {
                socketProfC.on('novo_chamado_emergencia', (data) => {
                    resolve(data);
                });
            });

            const promessaD = new Promise((resolve, reject) => {
                socketProfD.on('novo_chamado_emergencia', () => {
                    reject(new Error('Profissional D NÃO deveria ter recebido o chamado!'));
                });
                setTimeout(() => resolve('nao_recebeu'), 1000);
            });

            // 3. Enviar chamado APENAS para prof-C (simula lógica do controller)
            const socketIdC = profissionaisConectados.get('prof-C');
            io.to(socketIdC).emit('novo_chamado_emergencia', {
                chamado_id: 'chamado-999',
                categoria: 'Elétrica',
                distancia_metros: 1500
            });

            // 4. Verificar
            const [resultC, resultD] = await Promise.all([promessaC, promessaD]);

            expect(resultC.chamado_id).toBe('chamado-999');
            expect(resultC.categoria).toBe('Elétrica');
            expect(resultD).toBe('nao_recebeu');

            socketProfC.disconnect();
            socketProfD.disconnect();
        }, 10000);
    });

    // ─── TESTE DE SALA DO CLIENTE ───────────────────────────
    describe('Sala do Cliente (Room-based)', () => {

        it('deve enviar atualizacao_chamado apenas para o cliente da sala', async () => {
            // 1. Conectar 2 "clientes"
            const socketCliente1 = await conectarCliente();
            const socketCliente2 = await conectarCliente();

            // 2. Apenas Cliente 1 entra na sala
            socketCliente1.emit('entrar_sala_cliente', { cliente_id: 'cliente-001' });

            await new Promise(resolve => setTimeout(resolve, 200));

            // 3. Setup das promessas
            const promessa1 = new Promise((resolve) => {
                socketCliente1.on('atualizacao_chamado', (data) => {
                    resolve(data);
                });
            });

            const promessa2 = new Promise((resolve, reject) => {
                socketCliente2.on('atualizacao_chamado', () => {
                    reject(new Error('Cliente 2 NÃO deveria receber a atualização!'));
                });
                setTimeout(() => resolve('nao_recebeu'), 1000);
            });

            // 4. Emitir para a sala do cliente 1
            io.to('cliente:cliente-001').emit('atualizacao_chamado', {
                chamado_id: 'chamado-aaa',
                status_novo: 'a_caminho',
                mensagem: 'Profissional aceitou!'
            });

            // 5. Verificar
            const [result1, result2] = await Promise.all([promessa1, promessa2]);

            expect(result1.status_novo).toBe('a_caminho');
            expect(result2).toBe('nao_recebeu');

            socketCliente1.disconnect();
            socketCliente2.disconnect();
        }, 10000);
    });

    // ─── TESTE DE DESCONEXÃO ────────────────────────────────
    describe('Desconexão Limpa', () => {

        it('deve remover profissional do mapa ao desconectar', async () => {
            const socketProfE = await conectarCliente();
            socketProfE.emit('ficar_online', { profissional_id: 'prof-E' });

            await new Promise(resolve => setTimeout(resolve, 200));
            expect(profissionaisConectados.has('prof-E')).toBe(true);

            // Desconectar
            socketProfE.disconnect();

            // Aguarda o processamento do evento disconnect
            await new Promise(resolve => setTimeout(resolve, 500));

            expect(profissionaisConectados.has('prof-E')).toBe(false);
        }, 10000);
    });
});
