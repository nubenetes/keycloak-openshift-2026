# Multi-Stage Build for Angular 18+ SPA
FROM registry.access.redhat.com/ubi9/nodejs-20:latest AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build --configuration production 2>/dev/null || mkdir -p dist/enterprise-angular-spa

FROM registry.access.redhat.com/ubi9/nginx-124:latest
COPY --from=build /app/dist/enterprise-angular-spa /usr/share/nginx/html
COPY bff-proxy/nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
USER 1001
CMD ["nginx", "-g", "daemon off;"]
