server '18.116.35.107', user: 'deploy', roles: %w{app db web}
set :rails_env, 'production'

# set :ssh_options, {
#   forward_agent: true, 
#   auth_methods: %w[publickey],
#   keys: %w[~/lantiamasterkeypair.pem]
#  }

