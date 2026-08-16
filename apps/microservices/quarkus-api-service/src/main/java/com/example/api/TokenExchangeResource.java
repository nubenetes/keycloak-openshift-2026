package com.example.api;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.jwt.JsonWebToken;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;

/**
 * Demonstrates RFC 8693 OAuth 2.0 Token Exchange
 * Allows an API service to exchange an inbound user token for a downstream service token
 */
@Path("/api/v1/exchange")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class TokenExchangeResource {

    @Inject
    JsonWebToken jwt;

    @ConfigProperty(name = "quarkus.oidc.auth-server-url")
    String authServerUrl;

    @ConfigProperty(name = "quarkus.oidc.client-id")
    String clientId;

    @ConfigProperty(name = "quarkus.oidc.credentials.secret")
    String clientSecret;

    @POST
    @Path("/call-downstream")
    public Response callDownstreamWithDelegatedToken(@QueryParam("targetAudience") @DefaultValue("downstream-payment-service") String targetAudience) {
        try {
            String rawIncomingToken = jwt.getRawToken();
            if (rawIncomingToken == null || rawIncomingToken.isEmpty()) {
                return Response.status(Response.Status.UNAUTHORIZED).entity(Map.of("error", "Missing incoming bearer token")).build();
            }

            // Construct RFC 8693 Token Exchange Request to Keycloak /token endpoint
            String tokenEndpoint = authServerUrl + "/protocol/openid-connect/token";
            String requestBody = "grant_type=" + "urn:ietf:params:oauth:grant-type:token-exchange" +
                    "&client_id=" + clientId +
                    "&client_secret=" + clientSecret +
                    "&subject_token=" + rawIncomingToken +
                    "&subject_token_type=urn:ietf:params:oauth:token-type:access_token" +
                    "&requested_token_type=urn:ietf:params:oauth:token-type:access_token" +
                    "&audience=" + targetAudience;

            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(tokenEndpoint))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            return Response.ok(Map.of(
                    "status", "TOKEN_EXCHANGED",
                    "targetAudience", targetAudience,
                    "keycloakResponseCode", response.statusCode(),
                    "responsePayload", response.body()
            )).build();

        } catch (Exception e) {
            return Response.serverError().entity(Map.of("error", e.getMessage())).build();
        }
    }
}
