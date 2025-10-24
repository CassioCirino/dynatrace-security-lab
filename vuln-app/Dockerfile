FROM node:18-alpine
WORKDIR /opt/vuln-app
COPY package.json package.json
RUN npm install --omit=dev
COPY . .
RUN mkdir -p /opt/vuln-app/data /opt/vuln-app/logs && chmod -R 0777 /opt/vuln-app/data /opt/vuln-app/logs
EXPOSE 3000
CMD ["node","server.js"]
