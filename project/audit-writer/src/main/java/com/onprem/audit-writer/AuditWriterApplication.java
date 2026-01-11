package com.onprem.audit.writer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.Map;

@SpringBootApplication
@RestController
public class AuditWriterApplication {

    private final JdbcTemplate jdbcTemplate;

    public AuditWriterApplication(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public static void main(String[] args) {
        SpringApplication.run(AuditWriterApplication.class, args);
    }

    /**
     * Audit event write endpoint
     * - append-only
     * - no read/update/delete
     */
    @PostMapping("/audit")
    public void writeAudit(@RequestBody Map<String, Object> payload) {

        String sql = """
            INSERT INTO %s.%s (event_type, payload, created_at)
            VALUES (?, ?::jsonb, ?)
            """.formatted(
                System.getenv("DB_AUDIT_SCHEMA"),
                System.getenv("DB_AUDIT_TABLE")
        );

        jdbcTemplate.update(
            sql,
            payload.getOrDefault("event_type", "UNKNOWN"),
            payload.getOrDefault("payload", payload).toString(),
            OffsetDateTime.now()
        );
    }
}

