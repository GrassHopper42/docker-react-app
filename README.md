# Docker + Github Action

> 인프런 <따라하며 배우는 도커 CI>강의 실습을 위한 repo입니다.

강의에서는 무료라며 `Travis CI`를 사용하지만 유료플랜으로 바뀌었고 다시 쓰지 않을것 같아 연습삼아 `Github Action`으로 대체했다.  
CRA로 생성한 기본 리액트 앱뿐이라 큰 효용은 없지만 익숙해지기 위해 `npm` 대신 `yarn berry`로 대체했다.  
이 문서도 굳이 작성할 필요는 없었지만 md에 익숙해지기 위해 그냥 써봤다.

## Hello World

1. 프로젝트 디렉토리 생성 && yarn berry 적용

   ```zsh
   mkdir docker-react-app && cd docker-react-app
   yarn init
   yarn set version berry
   ```

2. CRA로 리액트 앱 생성

   ```zsh
   yarn create react-app docker-react-app
   ```

## 도커 개발환경 세팅

1. Dockerfile.dev 작성

   ```dockerfile
   FROM node:alpine
   WORKDIR /usr/src/app
   COPY ./ ./
   RUN yarn set version berry
   RUN yarn
   CMD ["yarn", "start"]
   ```

   > 굳이 yarn을 한번 더 실행해줘야할까라는 의문이 들긴 하지만 컨테이너를 생성했을때 메세지가 길어지는게 괜히찝찝해서 때문에 이미지 만들때 미리 실행했다.

2. docker-compose.yml 작성

   ```yml
   version: "3"
   services:
   react:
     build:
       context: .
       dockerfile: Dockerfile.dev
     ports:
       - "3000:3000"
     volumes:
       - ./:/usr/src/app
     stdin_open: true
   tests:
     build:
       context: .
       dockerfile: Dockerfile.dev
     volumes: -./:usr/src/app
     command: ["yarn", "test"]
   ```

3. 컨테이너 생성

   ```zsh
   docker-compose up
   ```

## 빌드&배포

리액트 앱을 빌드하고 nginx 컨테이너 위에 이미지를 돌린다.

1. Dockerfile작성 및 이미지 빌드

   이미지 사이즈를 줄이기 위해 멀티스테이지 빌드 활용.

   ```dockerfile
   FROM node:alpine as builder
   WORKDIR "/usr/src/app"
   COPY package.json .
   COPY yarn.lock .
   RUN yarn install
   COPY ./ ./
   RUN yarn build

   FROM nginx
   COPY --from=builder /usr/src/app/build /usr/share/nginx/html
   ```

   ```zsh
   docker build -t docker-react-app ./
   ```

2. 컨테이너 실행

   ```zsh
   docker run -it -p 8080:80 docker-react-app
   ```

## Github Action 활용해서 CI환경 구축

> 앞에서 말했듯 강의는 `Travis CI`를 활용했지만 나는 `Github Actions`를 활용해 유사한 환경을 구축했다.
> 그 과정에서 있었던 Trouble Shooting도 같이 적는다.

1. Github Action 생성

   Github Action을 생성하는 방법은 두가지다.

   - 자체적으로 레포 최상위에 `.github/workflows`디렉토리를 생성하고 그 아래 `yml`파일을 만들어 주거나

   - Github Repository에 Actions탭에서 Github에서 추천하는 템플릿을 이요하는 방법이다.

   나는 두번째 방법에서 Docker build 템플릿을 살짝 수정해 사용했다.

   ```yml
   # .github/workflows/test-github-actions.yml
   name: learn-github-actions

   on:
     # master 브랜치에 push나 pull_request가 발생하면 실행되도록 설정
     push:
       branches: [master]
     pull_request:
       branches: [master]

   jobs:
     build:
       runs-on: ubuntu-latest

       steps:
         - uses: actions/checkout@v2
         - name: Build Message
           run: echo "Start Creating an image with Dockerfile"
         - name: Build the Docker image
           run: docker build . --file Dockerfile.dev --tag docker-react-app
         - name: Test
           run: docker run docker-react-app yarn test -- --coverage
         - name: Test Complete Message
           run: echo "Test Success"
   ```
