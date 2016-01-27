require! { process, dockerode: Docker, express, 'body-parser' }

docker = new Docker!

err, containers <-! docker.list-containers  all: true
console.log containers

err, broker <-! docker.create-container Image: \databox-data-broker:latest name: \broker Tty: true

# TODO: Find some way to trap all exit and clean up asynchronously
process.on \SIGINT !->
  <-! broker.stop
  <-! broker.remove
  process.exit!

err, stream <-! broker.attach stream: true stdout: true stderr: true
stream.pipe process.stdout

err, data <-! broker.start

err, hello-world <-! docker.create-container Image: \databox-hello-world:latest name: \hello-world

err, data <-! hello-world.start PortBindings: '8080/tcp': [ HostPort: \8081 ]

app = express!

app.enable 'trust proxy'

app.use express.static 'static'

app.use body-parser.urlencoded extended: false

app.post '/list-apps' (req, res) !->
  err, containers <-! docker.list-containers all: req.body.all
  containers |> JSON.stringify |> res.end

app.post '/list-store' (req, res) !->
  res.end '{}'

app.post '/400' (req, res) !->
  res.write-head 400
  res.end!

app.listen (process.env.PORT or 8080)
