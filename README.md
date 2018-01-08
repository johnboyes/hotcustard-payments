[![CircleCI](https://circleci.com/gh/johnboyes/hotcustard-payments.svg?style=shield)](https://circleci.com/gh/johnboyes/hotcustard-payments)

# hotcustard-payments

Allow members of Hot Custard (social sports club) to see their payments due and historical transactions

## Running the application

Setup:
- start Redis: `redis-server`
- populate the Redis datastore: `bundle exec ruby populate_datastore.rb`

Start the application:

- `foreman start`

- You can then view the app by visiting: http://localhost:5000/payments

## Running the tests

Before running the tests, you must first:
- start Redis: `redis-server`
- populate the Redis datastore: `bundle exec ruby populate_datastore.rb`

Then you can run the tests:

`bundle exec rspec`
