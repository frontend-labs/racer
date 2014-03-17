module.exports = function(grunt) {
  grunt.file.defaultEncoding = 'utf8';
  cfg = grunt.file.readJSON('GruntConfig.json');
  var version = grunt.file.read('last_commit').replace(/\n|<br\s*\/?>/gi, "");
  var defaultOptsTmpl = {
      requireConfigFile: 'RequireConfig.js'
  };
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    // clean
    clean: {
      options: {force: true},
      build: {
        src: [cfg.js_compiled_source_path]
      }
    },
    //coffee
    coffee: {
      glob_to_multiple: {
        options: {
          bare: true
        },
        expand: true,
        cwd: cfg.coffee_source_path, // all the source
        src: ['**/*.coffee','!**/_*.coffee'], // Pattern to match, relative to the cwd.
        dest: cfg.js_compiled_source_path,
        ext: '.js'
      }
    },
    //concat
    concat: {
      options: {
        stripBanners: true
      }
    },
    //uglify
    uglify: {
      options: {
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("dd/mm/yyyy") %> */\n',
        mangle: false,
        compress: {
          drop_console: true
        }
      },
      js: {
        files: [{
          expand: true,
          cwd: cfg.js_compiled_source_path, // all the source
          src: '**/*.js', // pattern relative to cwd
          dest: cfg.js_min_source_path,
        }]
      }
    },
    //watch
    watch: {
      javascript: {
        files: [cfg.coffee_source_path+'**/*.coffee'],
        tasks: ['coffee'],
        options: {
          interrupt: true
        }
      },
    },
    //jshint
    jshint: {
      options: {
        jshintrc : '.jshintrc',
        "smarttabs" : true
      },
      js: [cfg.js_source_path+'**/*.js', '!'+cfg.js_source_path+'libs/*.js', '!'+cfg.js_source_path+'libs/utils/*.js', '!'+cfg.js_source_path+'libs/jquery/*.js', '!'+cfg.js_source_path+'libs/yoson/old_modules/*.js', '!'+cfg.js_source_path+'libs/yoson/data/*.js']
    },
    //for unit tests
    connect: {
        test: {
            options:{
                port: cfg.jasmine_port,
                base: '.'
            }
        }
    },
    jasmine:{
        requirejs:{
            src: cfg.js_source_path + 'src/**/*.js',
            options: {
                specs: 'spec/**/Spec*.js',
                helpers: 'test/spec/*Helper.js',
                host: cfg.jasmine_url + ':' + cfg.jasmine_port+'/',
                template: require('grunt-template-jasmine-requirejs'),
                templateOptions: defaultOptsTmpl
            }
        }
    },
    casperjs: {
        phatomjs:{
            options: {
                casperjsOptions: [ '--engine=phantomjs' ]
            }
        },
        slimerjs:{
            options: {
                casperjsOptions: [ '--engine=slimerjs' ]
            }
        },
        files: [cfg.casperjs_path + '**/*.js']
    }
  });
  //loadNpmTasks
  grunt.loadNpmTasks('grunt-contrib-clean');

  grunt.loadNpmTasks('grunt-replace');

  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-uglify');

  grunt.loadNpmTasks('grunt-contrib-watch');
  //tasks for tests
  //módulo para emular la conexión por consola de los tests
  grunt.loadNpmTasks('grunt-contrib-connect');
  //Load the plugin that provides the jasmine test
  grunt.loadNpmTasks('grunt-contrib-jasmine');

  // load tasks
  grunt.task.loadTasks('grunt/custom_tasks/');

  //registerTask

  grunt.registerTask('cafe', ['clean', 'coffee']);
  grunt.registerTask('js_source', ['concat']);

  grunt.registerTask('javascript', ['js_source', 'jshint', 'uglify']); // 'uglify'
  //specs
  //grunt.registerTask('spec', ['connect:test', 'jasmine:requirejs']);
  //grunt.registerTask('atdd', ['casperjs:slimerjs', 'casperjs']);
  //grunt.registerTask('suite-unit-tests', ['atdd']);

  // Run Default task(s).
  grunt.registerTask('default', ['cafe', 'javascript']); // 'replace']);
};

