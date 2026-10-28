package com.myatlas.services.media;

import org.springframework.boot.SpringApplication;

public class TestMediaApplication {

	public static void main(String[] args) {
		SpringApplication.from(MediaApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
