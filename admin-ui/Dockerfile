# 1. 빌드 (Node.js)
FROM node:18-alpine as build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

# 2. 실행 (Nginx - 웹 서버 표준 포트가 80번이야!)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# 리액트 라우터(새로고침 문제 해결) 설정
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]