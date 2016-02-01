require! { process, dockerode: Docker, express, 'body-parser' }

docker = new Docker!

get-broker = (callback) ->
  err, containers <-! docker.list-containers  all: true
  for container in containers
    if ~container.Names.index-of \/broker
      container.Id |> docker.get-container |> callback
      return
  err, broker <-! docker.create-container Image: \databox-data-broker:latest name: \broker Tty: true
  err, stream <-! broker.attach stream: true stdout: true stderr: true
  stream.pipe process.stdout
  callback broker

#err, hello-world <-! docker.create-container Image: \databox-hello-world:latest name: \hello-world

#err, data <-! hello-world.start PortBindings: '8080/tcp': [ HostPort: \8081 ]

app = express!

app.enable 'trust proxy'

app.use express.static 'static'

app.use body-parser.urlencoded extended: false

app.post '/get-broker-status' (req, res) !->
  broker <-! get-broker
  err, data <-! broker.inspect
  res.end data.State.Status

app.post '/toggle-broker-status' (req, res) !->
  broker <-! get-broker
  err, data <-! broker.inspect
  if data.State.Status is \created or data.State.Status is \exited
    err, data <-! broker.start
    err, data <-! broker.inspect
    res.end data.State.Status
  else
    err, data <-! broker.stop
    err, data <-! broker.inspect
    res.end data.State.Status

app.post '/list-apps' (req, res) !->
  err, containers <-! docker.list-containers all: req.body.all
  containers |> JSON.stringify |> res.end

app.post '/list-store' (req, res) !->
  res.end '{}'

app.post '/400' (req, res) !->
  res.write-head 400
  res.end!

app.listen (process.env.PORT or 8080)
