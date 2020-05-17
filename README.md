# Spawn Polynote Notebooks Fargate
In this repository you can find all files to easily spin up Polynote Notebooks on AWS.  
There are some prerequisites to get this to work. For example, you need the following AWS services up and running: 

- An  ECS cluster
- An application load balancer
- An hosted zone and domain within Route53

You'll also need the following software installed on your computer:

- Terraform
- Docker (optionally, if you want to make adjusmtents to the Polynote config file)

# How to
Head over to the terraform folder, edit the vars.tfvars to your needs and run the following commands:

```
terraform init
```

```
terraform apply -var-file=vars.tfvars
```

Apply by typing 'yes'

## Destroying
```
terraform destroy -var-file=vars.tfvars
```
Apply by typing 'yes'
