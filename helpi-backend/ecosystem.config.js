module.exports = {
  apps: [
    {
      name: 'helpi-api',
      script: './src/server.js',
      // SEGURANÇA V8: Socket.IO usa Map() em memória para rastrear profissionais online.
      // O modo 'cluster' cria múltiplos workers, cada um com seu próprio Map(), quebrando
      // o rastreamento de sockets. Para usar cluster, é necessário:
      // 1. npm install @socket.io/redis-adapter redis
      // 2. Migrar profissionaisConectados para Redis
      // Até lá, usamos fork (instância única) para garantir integridade.
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'development',
      },
      env_production: {
        NODE_ENV: 'production',
      },
      log_date_format: 'YYYY-MM-DD HH:mm Z',
      out_file: './logs/pm2-out.log',
      error_file: './logs/pm2-error.log',
      merge_logs: true,
    },
  ],
};
