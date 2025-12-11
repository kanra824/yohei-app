use axum::{routing::get, Router, Json};
use serde::Serialize;

#[derive(Serialize)]
struct Health { status: &'static str }

#[tokio::main]
async fn main() {
    // initialize tracing
    tracing_subscriber::fmt::init();

    // build our application with a route
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health));

    // run it
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Hello from Axum!"
}

async fn health() -> Json<Health> {
    Json(Health { status: "ok" })
}
