GONAME         := "dex-k8s-authenticator"
TAG            := "latest"
E2E_GITHUB_SHA := `openssl rand -hex 4`
KIND_NODE_IP   := `kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}"`

all: build 

build:
	@echo "Building go binary ./bin/{{GONAME}}"
	go build -o bin/{{GONAME}} *.go

alias docker := container
container:
	@echo "Building container image"
	docker build -t getditto/{{GONAME}}:{{TAG}} .

clean:
	@echo "Cleaning"
	go clean
	rm -rf ./bin

lint:
	golangci-lint run

lint-fix: lint
	golangci-lint run --fix

up:
	docker build -t getditto/dex-k8s-authenticator:{{E2E_GITHUB_SHA}} .
	kind load docker-image getditto/dex-k8s-authenticator:{{E2E_GITHUB_SHA}}

	echo {{KIND_NODE_IP}}
	NODE_IP={{KIND_NODE_IP}} CI_TAG={{E2E_GITHUB_SHA}} envsubst < ./tests/e2e/helm/dex-overrides.yaml > /tmp/dex-overrides.yaml
	NODE_IP={{KIND_NODE_IP}} CI_TAG={{E2E_GITHUB_SHA}} envsubst < ./tests/e2e/helm/dex-k8s-auth-overrides.yaml > /tmp/dex-k8s-auth-overrides.yaml

	helm repo add dexidp https://charts.dexidp.io || true
	helm template -f /tmp/dex-overrides.yaml dex dexidp/dex | kubectl apply -f -
	kubectl describe deployment dex
	kubectl rollout status deploy dex -w

	helm template -f /tmp/dex-k8s-auth-overrides.yaml dex-k8s-authenticator ./charts/dex-k8s-authenticator | kubectl apply -f -
	kubectl describe deployment dex-k8s-authenticator
	kubectl rollout status deploy dex-k8s-authenticator -w

alias pf := portforward
alias port-forward := portforward

portforward:
	kubectl port-forward deployment/dex-k8s-authenticator 5555 5555
  