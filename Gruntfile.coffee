msgflo_nodejs = require 'msgflo-nodejs'
msgflo = require 'msgflo'
path = require 'path'

module.exports = ->
  grunt = @
  @initConfig
    pkg: @file.readJSON 'package.json'

    # Updating the package manifest files
    noflo_manifest:
      update:
        files:
          'package.json': ['graphs/*', 'components/*']

    yamllint:
      participants: ['participants/*.yml']
    updateforeign:
      participants: ['participants/*.yml']
    register:
      participants: ['participants/*.yml']
    createMarkup:
      participants: ['participants/*.yml']

  @loadNpmTasks 'grunt-yamllint'
  @loadNpmTasks 'grunt-noflo-manifest'
  @task.registerMultiTask 'updateforeign', ->
    conf = grunt.file.readJSON 'package.json'
    foreigns = []
    @files.forEach (file) ->
      file.src.forEach (src) ->
        foreigns.push path.basename src, path.extname src
    conf.msgflo = {} unless conf.msgflo
    conf.msgflo.components = {} unless conf.msgflo.components
    for k, v of conf.msgflo.components
      delete conf.msgflo.components[k] if v is '#FOREIGN'
    for f in foreigns
      conf.msgflo.components["#{conf.name}/#{f}"] = '#FOREIGN'
    grunt.file.write 'package.json', JSON.stringify(conf, null, 2), 'utf-8'

  @task.registerMultiTask 'register', ->
    done = @async()
    options = @options
      broker: 'mqtt://localhost'
    grunt.verbose.writeln "Connecting to MsgFlo broker #{options.broker}"
    messaging = msgflo_nodejs.transport.getClient options.broker
    connected = false
    setTimeout ->
      return if connected
      done new Error "Failed to connect to #{options.broker}"
    , 5000
    messaging.connect (err) =>
      return done err if err
      connected = true
      defs = []
      @files.forEach (file) ->
        file.src.forEach (src) ->
          def = grunt.file.readYAML src
          def.id = path.basename src, path.extname src unless def.id
          def.role = path.basename src, path.extname src unless def.role
          defs.push msgflo.foreignParticipant.mapPorts def
      todo = defs.length
      for def in defs
        grunt.log.writeln "Registering #{def.role} (#{def.component})"
        msgflo.foreignParticipant.register messaging, def, (err) ->
          return done err if err
          todo--
          return done() if todo < 1
  
  @task.registerMultiTask 'createMarkup', ->
        mqttArtifacts = []
        artifact = ""
        @files.forEach (file) ->
          artifact += "^ component ^ source ^ label ^ \n"
          file.src.forEach (src) ->
            readYaml = grunt.file.readYAML src
            artifact += "|#{readYaml.component} |"
            if readYaml.source?
              artifact += "#{readYaml.source}"
            else
              artifact += " n/a "
            artifact +="|#{readYaml.label}|\n"
        grunt.log.writeln "#{artifact}"
      
          

  @registerTask 'test', ['noflo_manifest', 'updateforeign', 'yamllint']
  @registerTask 'default', ['test']
