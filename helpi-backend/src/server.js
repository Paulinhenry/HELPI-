const http = require('http');
const { Server } = require('socket.io');
const app = require('./app');

// 1. Cria o servidor HTTP raiz (o Express roda lá dentro)
const servidorHttp = http.createServer(app);

// 2. Liga o Radar (Socket.IO) ao nosso servidor com permissão total (CORS) para o Flutter
const io = new Server(servidorHttp, {
    cors: {
        origin: "*", // Permite que o telemóvel se conecte de qualquer rede
        methods: ["GET", "POST", "PUT"]
    }
});

// 3. O "Ouvinte" - Deteta quando um telemóvel abre a aplicação
io.on('connection', (socket) => {
    console.log(`🟢 [RADAR] Telemóvel conectado! ID da sessão: ${socket.id}`);

    // Aqui poderemos ouvir quando o profissional diz "Estou Online"
    // socket.on('profissional_online', (dados) => { ... })

    // Deteta quando a pessoa fecha a aplicação ou perde a internet
    socket.on('disconnect', () => {
        console.log(`🔴 [RADAR] Telemóvel desconectado. ID: ${socket.id}`);
    });
});

// 4. Injeta o 'io' no 'app' para podermos usar o radar nas nossas rotas!
app.set('io', io);

const PORT = process.env.PORT || 3000;

// 5. ATENÇÃO: Agora quem faz o 'listen' é o servidorHttp e não o app
servidorHttp.listen(PORT, () => {
    console.log(`🚀 Motor Helpi a rodar na porta ${PORT} com WebSockets ativos!`);
});