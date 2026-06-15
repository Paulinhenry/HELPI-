const app = require('./app');
const http = require('http');
const socketIo = require('socket.io');

const server = http.createServer(app);
const io = socketIo(server);

// Disponibiliza o IO para os controladores
app.set('io', io);

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
    console.log(`🚀 Helpi API rodando em http://localhost:${PORT}`);
    console.log(`📄 Documentação disponível em http://localhost:${PORT}/api-docs`);
});