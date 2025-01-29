SLURM_JWT=$(cat data/slurm/secret/jwt_token.txt)
curl -X 'GET' -v 'http://localhost:6820/slurm/v0.0.39/node/node01' --location --silent --show-error -H "X-SLURM-USER-NAME: root" -H "X-SLURM-USER-TOKEN: $SLURM_JWT"
# curl -v --unix-socket data/slurm/tmp/slurmrestd.socket 'http://localhost:6820/slurm/v0.0.39/ping'