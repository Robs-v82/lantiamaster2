
# ACCESS TOTHE SERVER
ssh -i "server-keys/lantiamaster-key-pair.pem" ubuntu@ec2-3-134-94-157.us-east-2.compute.amazonaws.com

# ACCESS THE PRODUCITON CONSOLE
RACK_ENV=production bundle exec rails console