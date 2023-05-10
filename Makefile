IMAGE_NAME=sshts

image:
	docker build -t $(IMAGE_NAME) docker

run: image
	docker run -it --rm -v $(PWD):/app $(IMAGE_NAME) bash