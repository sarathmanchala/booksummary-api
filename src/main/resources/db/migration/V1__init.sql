-- V1__init.sql : initial schema for booksummary-api

CREATE TABLE users (
                       id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                       email         VARCHAR(255) NOT NULL,
                       password_hash VARCHAR(255),
                       display_name  VARCHAR(100) NOT NULL,
                       role          VARCHAR(20)  NOT NULL DEFAULT 'USER',
                       created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                       CONSTRAINT uq_users_email UNIQUE (email),
                       CONSTRAINT ck_users_role  CHECK (role IN ('USER', 'MODERATOR', 'ADMIN'))
);

CREATE TABLE authors (
                         id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                         name       VARCHAR(200) NOT NULL,
                         created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE books (
                       id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                       title       VARCHAR(300) NOT NULL,
                       isbn        VARCHAR(20),
                       description TEXT,
                       created_by  BIGINT       NOT NULL,
                       created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                       CONSTRAINT uq_books_isbn       UNIQUE (isbn),
                       CONSTRAINT fk_books_created_by FOREIGN KEY (created_by) REFERENCES users (id)
);

CREATE TABLE book_authors (
                              book_id   BIGINT NOT NULL,
                              author_id BIGINT NOT NULL,
                              PRIMARY KEY (book_id, author_id),
                              CONSTRAINT fk_book_authors_book   FOREIGN KEY (book_id)   REFERENCES books (id)   ON DELETE CASCADE,
                              CONSTRAINT fk_book_authors_author FOREIGN KEY (author_id) REFERENCES authors (id) ON DELETE CASCADE
);

CREATE TABLE summaries (
                           id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                           book_id    BIGINT       NOT NULL,
                           user_id    BIGINT       NOT NULL,
                           body       TEXT         NOT NULL,
                           status     VARCHAR(20)  NOT NULL DEFAULT 'PUBLISHED',
                           created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                           updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                           CONSTRAINT fk_summaries_book   FOREIGN KEY (book_id) REFERENCES books (id),
                           CONSTRAINT fk_summaries_user   FOREIGN KEY (user_id) REFERENCES users (id),
                           CONSTRAINT ck_summaries_status CHECK (status IN ('PUBLISHED', 'HIDDEN', 'REMOVED'))
);

CREATE TABLE quotes (
                        id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                        book_id     BIGINT       NOT NULL,
                        user_id     BIGINT       NOT NULL,
                        text        TEXT         NOT NULL,
                        page_number INTEGER,
                        status      VARCHAR(20)  NOT NULL DEFAULT 'PUBLISHED',
                        created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                        CONSTRAINT fk_quotes_book     FOREIGN KEY (book_id) REFERENCES books (id),
                        CONSTRAINT fk_quotes_user     FOREIGN KEY (user_id) REFERENCES users (id),
                        CONSTRAINT ck_quotes_text_len CHECK (char_length(text) <= 300),
                        CONSTRAINT ck_quotes_page     CHECK (page_number IS NULL OR page_number > 0),
                        CONSTRAINT ck_quotes_status   CHECK (status IN ('PUBLISHED', 'HIDDEN', 'REMOVED'))
);

CREATE TABLE votes (
                       id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                       user_id     BIGINT      NOT NULL,
                       target_type VARCHAR(20) NOT NULL,
                       target_id   BIGINT      NOT NULL,
                       value       SMALLINT    NOT NULL,
                       created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                       CONSTRAINT fk_votes_user        FOREIGN KEY (user_id) REFERENCES users (id),
                       CONSTRAINT ck_votes_value       CHECK (value IN (1, -1)),
                       CONSTRAINT ck_votes_target_type CHECK (target_type IN ('SUMMARY', 'QUOTE')),
                       CONSTRAINT uq_votes_user_target UNIQUE (user_id, target_type, target_id)
);

CREATE TABLE refresh_tokens (
                                id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                user_id    BIGINT      NOT NULL,
                                token_hash VARCHAR(64) NOT NULL,                  -- SHA-256 hex, never the raw token
                                expires_at TIMESTAMPTZ NOT NULL,
                                revoked_at TIMESTAMPTZ,
                                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                                CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash),
                                CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE reports (
                         id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                         reporter_id BIGINT       NOT NULL,
                         target_type VARCHAR(20)  NOT NULL,
                         target_id   BIGINT       NOT NULL,
                         reason      VARCHAR(500) NOT NULL,
                         status      VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
                         created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
                         CONSTRAINT fk_reports_reporter        FOREIGN KEY (reporter_id) REFERENCES users (id),
                         CONSTRAINT ck_reports_target_type     CHECK (target_type IN ('SUMMARY', 'QUOTE')),
                         CONSTRAINT ck_reports_status          CHECK (status IN ('OPEN', 'RESOLVED', 'DISMISSED')),
                         CONSTRAINT uq_reports_reporter_target UNIQUE (reporter_id, target_type, target_id)
);

-- Indexes on foreign keys we will filter or join by
CREATE INDEX idx_summaries_book_id      ON summaries (book_id);
CREATE INDEX idx_summaries_user_id      ON summaries (user_id);
CREATE INDEX idx_quotes_book_id         ON quotes (book_id);
CREATE INDEX idx_quotes_user_id         ON quotes (user_id);
CREATE INDEX idx_books_created_by       ON books (created_by);
CREATE INDEX idx_book_authors_author_id ON book_authors (author_id);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);

-- Votes/reports lookups by target (the UNIQUE index starts with user_id, so it can't serve these)
CREATE INDEX idx_votes_target   ON votes (target_type, target_id);
CREATE INDEX idx_reports_target ON reports (target_type, target_id);