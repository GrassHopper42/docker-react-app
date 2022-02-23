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
         # image build 메세지 출력
         - name: Build Message
           run: echo "Start Creating an image with Dockerfile"
         # Docker image Build
         - name: Build the Docker image
           run: docker build . --file Dockerfile.dev --tag docker-react-app
         # build된 image test
         - name: Test
           run: docker run docker-react-app yarn test
         # Test 완료 메세지 출력
         - name: Test Complete Message
           run: echo "Test Success"
   ```

   수정을 마쳤으면 오른쪽 상단에서 Start commit버튼을 눌러 commit을 해준다.  
   바로 `Actions` 탭에 가보면 workflow에 따라 진행상황과 결과를 볼 수 있다.  
   처음에 몇가지 오류가 발생해 수정하고 코드를 `push`했을 때 test과정에서 문제가 생겼는데, job은 step에 따라 진행되므로 이 경우 test완료 메세지는 출력되지 않는다.

2. Trouble Shooting

   1. 처음엔 jobs에 test를 추가해 분리해보려고 했지만 이 경우 image를 찾지 못해서 실패했다.

      ```yml
      jobs:
        build:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v2
            - name: Build Message
              run: echo "Start Creating an image with Dockerfile"
            - name: Build the Docker image
              run: docker build . --file Dockerfile.dev --tag docker-react-app
        test:
          needs: build
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v2
            - name: Test
              run: docker run docker-react-app yarn test
            - name: Test Complete Message
              run: echo "Test Success"
      ```

      이미지 빌드와 컨테이너 실행을 분리시키려면 dockerhub를 거쳐야할 것 같다. 귀찮아서 그냥 합쳤다.

   2. test 스텝에서 강의를 따라하려고 `-- --coverage`를 입력했더니 오류가 발생해서 문제가 됐다.

      이걸 지워줬더니 문제는 해결됐지만 테스트를 성공하고 컨테이너를 빠져나오지 못해 다음 워크플로우로 진행이 안된다...  
      -it를 넣어주면 `the input device is not a TTY`오류가 떠서 자동 종료된다.

   3. 컨테이너 무한루프

      멘토님께 여쭤보고 얻은 결론은

      > **어차피 `Github Action`도 가상환경인데 굳이 컨테이너 두개를 거쳐서 테스트할 필요까진 없겠다.**

      테스트를 먼저 진행하고 테스트가 완료되면 이미지를 빌드하는 방식으로 수정했다.
      덤으로 tests와 build로 jobs를 분리시켜서 test와 build workflow를 변경해보았다. 기능적인 부분은 좀 더 알아봐야겠지만 시도와 경험에 의의를 뒀다.

      ```yml
      name: learn-github-actions

      on:
        push:
          branches: [master]
        pull_request:
          branches: [master]

      jobs:
        tests:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v2
            - name: Run tests
              run: yarn test
            - name: Test Complete Message
              run: echo "Test Success"

        build:
          needs: tests
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v2
            - name: Build Message
              run: echo "Start Creating an image with Dockerfile"
            - name: Build the Docker image
              run: docker build . --file Dockerfile.dev --tag docker-react-app
      ```
