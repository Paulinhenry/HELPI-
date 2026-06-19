FROM node:20-alpine

# Diretório de trabalho no container
WORKDIR /app

# Definir ambiente como produção
ENV NODE_ENV=production

# Instalar pm2 globalmente
RUN npm install pm2 -g

# Copiar package.json e package-lock.json (se existir)
COPY package*.json ./

# Instalar apenas dependências de produção
RUN npm ci --only=production

# Copiar código da aplicação
COPY . .

# Expor a porta que a API vai usar
EXPOSE 3000

# Usar PM2 para gerenciar o processo em cluster mode
CMD ["pm2-runtime", "start", "ecosystem.config.js"]
