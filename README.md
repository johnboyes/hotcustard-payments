[![CircleCI](https://circleci.com/gh/johnboyes/hotcustard-payments.svg?style=shield)](https://circleci.com/gh/johnboyes/hotcustard-payments)

# hotcustard-payments

Allow members of Hot Custard (social sports club) to see their payments due and historical transactions


## Local development

### Local development from scratch

#### Pre-requisites

- [Ruby](https://www.ruby-lang.org/en/)
- [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) (needed to run [Heroku Local](https://devcenter.heroku.com/articles/heroku-local))
- [Redis](https://redis.io/)

### Visual Studio Code Remote Container

The easiest way to set up your development environment (unless you have [Codespaces](#codespaces), which is even easier) is to use [Visual Studio Code](https://code.visualstudio.com/)'s [Remote Containers](https://code.visualstudio.com/docs/remote/containers) functionality:
  - Remote Containers [System requirements](https://code.visualstudio.com/docs/remote/containers#_system-requirements)
  - [Fork the project](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/working-with-forks) 
  - [Open the local project folder in a container](https://code.visualstudio.com/docs/remote/containers#_quick-start-open-an-existing-folder-in-a-container)

### Codespaces

If you have access to [GitHub Codespaces](https://github.com/features/codespaces/) (which allows full remote
development from within your browser) then all you need to do is [fork the project](https://docs.github.com/en/github/collaborating-with-issues-and-pull-requests/working-with-forks) and open it in Codespaces - easy!

### Setup (before running the web application or the tests)

1. Create a [`.env` file](https://devcenter.heroku.com/articles/heroku-local#set-up-your-local-environment-variables) in the root folder of your project
    - Ask a [core maintainer](.github/CODEOWNERS) for the values to populate the `.env` file with.

2. (if developing locally from scratch)

   Start Redis: `redis-server`

   (Not required on remote container or Codespaces, as they come with Redis already running)

3. Populate the Redis datastore: `heroku local release` (it's called release because it's the release step in production)


## Running the application

- `heroku local web`

- You can then view the app by visiting: http://localhost:5000/payments


## Running the tests

`bundle exec rspec`


## Updating dependencies

See the [DEPENDENCIES.md](.github/DEPENDENCIES.md)
