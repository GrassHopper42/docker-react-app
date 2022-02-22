FROM node:alpine as builder
WORKDIR "/usr/src/app"
COPY package.json .
COPY yarn.lock .
RUN yarn install
COPY ./ ./
RUN yarn build

FROM nginx
COPY --from=builder /usr/src/app/build /usr/share/nginx/html