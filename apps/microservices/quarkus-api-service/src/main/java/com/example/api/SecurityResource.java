package com.example.api;

import io.quarkus.security.Authenticated;
import jakarta.annotation.security.RolesAllowed;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.jwt.JsonWebToken;

import java.util.Map;

@Path("/api/v1/workloads")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
public class SecurityResource {

    @Inject
    JsonWebToken jwt;

    @GET
    @Path("/public")
    public Response publicEndpoint() {
        return Response.ok(Map.of(
            "status", "UP",
            "message", "Public telemetry endpoint - no authentication required."
        )).build();
    }

    @GET
    @Path("/user-info")
    @Authenticated
    public Response authenticatedUser() {
        return Response.ok(Map.of(
            "subject", jwt.getSubject(),
            "issuer", jwt.getIssuer(),
            "name", jwt.getName(),
            "groups", jwt.getGroups(),
            "claimNames", jwt.getClaimNames()
        )).build();
    }

    @GET
    @Path("/admin-action")
    @RolesAllowed({"realm-admin", "devops-engineer", "/Admins"})
    public Response adminPrivilegedAction() {
        return Response.ok(Map.of(
            "status", "AUTHORIZED",
            "action", "Triggering production configuration reload",
            "executor", jwt.getSubject()
        )).build();
    }
}
