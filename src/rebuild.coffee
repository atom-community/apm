rebuild = require 'electron-rebuild'

path = require 'path'

_ = require 'underscore-plus'
yargs = require 'yargs'

config = require './apm'
Command = require './command'
fs = require './fs'
Install = require './install'

module.exports =
class Rebuild extends Command
  @commandNames: ['rebuild']

  constructor: ->
    super()
    @atomDirectory = config.getAtomDirectory()
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')
    @electronRebuildPath = require.resolve('.bin/electron-rebuild')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """

      Usage: apm rebuild [<name> [<name> ...]]

      Rebuild the given modules currently installed in the node_modules folder
      in the current working directory.

      All the modules will be rebuilt if no module names are specified.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  forkNpmRebuild: (options, callback) ->
    process.stdout.write 'Rebuilding modules '

    rebuildArgs = ["--version", @electronVersion]
    rebuildArgs.push(["--which-module", options.argv._.join(',')])
    rebuildArgs.push(['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath()]...)
    rebuildArgs.push(@getNpmBuildFlags()...)

    fs.makeTreeSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    @fork(@electronRebuildPath, rebuildArgs, {env}, callback)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    config.loadNpm (error, @npm) =>
      @loadInstalledAtomMetadata =>
        @forkNpmRebuild options, (code, stderr='') =>
          if code is 0
            @logSuccess()
            callback()
          else
            @logFailure()
            callback(stderr)
