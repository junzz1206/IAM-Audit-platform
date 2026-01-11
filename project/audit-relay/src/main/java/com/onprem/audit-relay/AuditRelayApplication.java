package com.onprem.audit.relay;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AuditRelayApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuditRelayApplication.class, args);
    }
}

@Component
class RelayRunner {

    @PostConstruct
    public void run() {
        while (true) {
            // TODO: relay 작업 수행
            // 예: 큐 소비, 이벤트 전달 등

            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }
}

