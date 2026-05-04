init:
	cd live/prod && terraform init

plan:
	cd live/prod && terraform plan

apply:
	cd live/prod && terraform apply

destroy:
	cd live/prod && terraform destroy