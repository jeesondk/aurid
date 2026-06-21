# Dockerfile for Admin Console Rails application
# Multi-stage build for production and development

# Stage 1: Build stage
FROM ruby:3.2.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    libpq-dev \
    openssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    zlib-dev \
    git \
    nodejs \
    yarn \
    tzdata

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler:2.4.0

# Copy Gemfiles
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set --local without 'development test' && \
    bundle install --jobs $(nproc) --retry 3

# Copy application files
COPY . .

# Precompile assets (if needed)
# RUN bundle exec rails assets:precompile

# Stage 2: Runtime stage
FROM ruby:3.2.2-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    postgresql-client \
    openssl \
    libffi \
    libxml2 \
    libxslt \
    zlib \
    tzdata \
    nodejs \
    git

# Set working directory
WORKDIR /app

# Create app user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy from builder
COPY --from=builder --chown=appuser:appgroup /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=appuser:appgroup /app /app

# Switch to app user
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Default command
CMD ["bash", "-c", "rm -f tmp/pids/server.pid && bundle exec rails s -p 3000 -b '0.0.0.0'"]

# Alternative: Use puma in production
# CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
