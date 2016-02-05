require! { process, dockerode: Docker, express, 'body-parser', request, fs, portfinder }

const registry-url = 'amar.io:5000'

docker = new Docker!

container-exists = (name, callback) !->
  err, containers <-! docker.list-containers  all: true
  for container in containers
    if ~container.Names.index-of name
      container.Id |> docker.get-container |> callback
      return
  callback!

get-broker = (callback) !->
  container <-! container-exists \/broker
  if container?
    callback container
    return
  auth =
    serveraddress: "https://#registry-url/v2"
  err, stream <-! docker.pull 'databox-data-broker:latest' authconfig: auth
  err, broker <-! docker.create-container Image: "#registry-url/databox-data-broker:latest" name: \broker Tty: true
  console.log err
  err, stream <-! broker.attach stream: true stdout: true stderr: true
  stream.pipe process.stdout
  callback broker

app = express!

app.enable 'trust proxy'

app.use express.static 'static'

app.use body-parser.urlencoded extended: false

app.post '/get-broker-status' (req, res) !->
  broker <-! get-broker
  err, data <-! broker.inspect
  res.end data.State?.Status

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

app.post '/list-containers' (req, res) !->
  err, containers <-! docker.list-containers all: req.body.all
  containers |> JSON.stringify |> res.end

app.post '/list-images' (req, res) !->
  err, images <-! docker.list-images
  images |> JSON.stringify |> res.end

app.post '/list-store' (req, res) !->
  (error, response, body) <-! request "https://#registry-url/v2/_catalog"
  if error
    error |> JSON.stringify |> res.end
    return
  res.end body

app.post '/pull-app' (req, res) !->
  auth =
    serveraddress: "https://#registry-url/v2"

  name = req.body.name
  tag  = req.body.tag or \latest
  err, stream <-! docker.pull "#name:#tag" authconfig: auth
  stream.pipe res

app.post '/launch-app' (req, res) !->
  name = req.body.name
  tag  = req.body.tag or \latest
  err, port <-! portfinder.get-port
  err, container <-! docker.create-container Image: "#registry-url/#name:#tag" name
  err, data <-! container.start PortBindings: '8080/tcp': [ HostPort: "#port" ] #Binds: [ "#__dirname/apps/#name:/./:rw" ]
  { port } |> JSON.stringify |> res.end

app.post '/400' (req, res) !->
  res.write-head 400
  res.end!

app.listen (process.env.PORT or 8080)
