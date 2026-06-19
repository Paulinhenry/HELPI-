module.exports = {
  apps: [
    {
      name: 'helpi-api',
      script: './src/server.js',
      instances: 'max', // Utiliza todos os núcleos de CPU disponíveis
      exec_mode: 'cluster', // Modo cluster para escalabilidade horizontal no mesmo host
      env: {
        NODE_ENV: 'development',
      },
      env_production: {
        NODE_ENV: 'production',
      },
      log_date_format: 'YYYY-MM-DD HH:mm Z',
      out_file: './logs/pm2-out.log',
      error_file: './logs/pm2-error.log',
      merge_logs: true, // Combina logs de todas as instâncias em um só arquivo
    },
  ],
};
