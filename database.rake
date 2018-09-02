SYNC_APP_NAME = 'my-sync-app'

def config
  uri = URI(Rails.configuration.database_configuration['development']['url'])

  {
    'username' => uri.user,
    'password' => uri.password,
    'host'     => uri.host,
    'port'     => uri.port || '5432',
    'database' => uri.path[1..-1]
  }
end

def db_dump_file
  Rails.root.join('tmp/latest.dump').to_s
end

namespace :database do
  task kill_connections: :environment do
    sql =
      'SELECT pg_terminate_backend(pid)
         FROM pg_stat_activity
        WHERE datname = current_database()
          AND pid != pg_backend_pid()'
    ActiveRecord::Base.connection.execute(sql)
    ActiveRecord::Base.connection.close
  end

  desc 'Creates and then downloads newest staging dump'
  task sync: [:environment] do
    Bundler.with_clean_env do
      system('heroku run sync -a ' + SYNC_APP_NAME)
    end

    Rake::Task['database:sync_download'].invoke
  end

  desc 'Downloads newest staging dump'
  task sync_download: [:environment] do
    Bundler.with_clean_env do
      puts 'Getting presigned download URL...'
      dump_url = `heroku run --no-notify --no-tty sync_url -a #{SYNC_APP_NAME} 2> /dev/null`.presence&.strip || fail('could not get presigned download URL')

      # Download file from S3
      system(format('curl -o %s "%s"', db_dump_file, dump_url)) || fail('could not download dump')

      system('pg_restore -l tmp/latest.dump > /dev/null') || fail('invalid dump')
    end

    Sidekiq::Queue.new.clear
    Sidekiq::RetrySet.new.clear

    Rake::Task['database:kill_connections'].invoke
    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke

    pg_restore_opts = '--verbose --no-acl --no-owner'
    Bundler.clean_system format('PGPASSWORD=%s pg_restore %s -h %s -p %d -U %s -d %s %s',
                                config['password'], pg_restore_opts, config['host'],
                                config['port'], config['username'], config['database'],
                                db_dump_file) || fail('could not restore')

    File.delete(db_dump_file)

    Rake::Task['db:environment:set'].invoke
  end
end
