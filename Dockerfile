# Fase 1: Construcción (Compilación) de la aplicación React
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Fase 2: Producción (Servidor web para los archivos compilados)
FROM nginx:stable-alpine
# Copia los archivos estáticos generados en la fase 1 a la carpeta pública de Nginx
COPY --from=build /app/build /usr/share/nginx/html
# Expone el puerto 80 del contenedor
EXPOSE 80
# Comando para iniciar el servidor Nginx
CMD ["nginx", "-g", "daemon off;"]
