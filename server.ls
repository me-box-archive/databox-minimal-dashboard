require! { process, dockerode: Docker, express, 'body-parser' }

docker = new Docker!

err, container <-! docker.create-container Image: \docker/whalesay Cmd: ['cowsay', 'boo'] name: \cowsay Tty: true

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
