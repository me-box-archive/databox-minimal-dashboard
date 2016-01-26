require! { process, dockerode: Docker, express, 'body-parser' }

docker = new Docker!

err, containers <-! docker.list-containers  all: true
console.log containers

err, container <-! docker.create-container Image: \databox-data-broker:latest name: \broker Tty: true

# TODO: Find some way to trap all exit and clean up asynchronously
process.on \SIGINT !->
  <-! container.stop
  <-! container.remove
  process.exit!

err, stream <-! container.attach stream: true stdout: true stderr: true
stream.pipe process.stdout

err, data <-! container.start

app = express!

app.enable 'trust proxy'

app.use express.static 'static'

app.use body-parser.urlencoded extended: false

handle-vote = (req, res, vote) !->
  unless req.body.title
    res.write-head 400
    res.end!
    return

app.post '/poll/yes' (req, res) !-> handle-vote req, res, \yes

app.post '/poll/no'  (req, res) !-> handle-vote req, res, \no

app.post '/poll/stats' (req, res) !->
  unless req.body.title
    res.write-head 400
    res.end!
    return

app.listen (process.env.PORT || 8080)
