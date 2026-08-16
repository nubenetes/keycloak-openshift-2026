import { createBackendModule } from '@backstage/backend-plugin-api';
import { oidcAuthenticator } from '@backstage/plugin-auth-backend-module-oidc-provider';
import { authProvidersExtensionPoint, createOAuthProviderFactory } from '@backstage/plugin-auth-node';

/**
 * Enterprise Keycloak OIDC Authentication Module for Backstage IDP
 */
export const authModuleKeycloakProvider = createBackendModule({
  pluginId: 'auth',
  moduleId: 'keycloak-provider',
  register(reg) {
    reg.registerInit({
      deps: {
        providers: authProvidersExtensionPoint,
      },
      async init({ providers }) {
        providers.registerProvider({
          providerId: 'oidc',
          factory: createOAuthProviderFactory({
            authenticator: oidcAuthenticator,
            async signInResolver(info, ctx) {
              const { result } = info;
              const { profile } = result.fullProfile;

              if (!profile.email) {
                throw new Error('Login failed: Token did not contain an email address claim.');
              }

              // Extract user identity matching Backstage catalog user entity
              const [userEntityRef] = profile.email.split('@');
              return ctx.issueToken({
                claims: {
                  sub: `user:default/${userEntityRef}`,
                  ent: [`user:default/${userEntityRef}`],
                },
              });
            },
          }),
        });
      },
    });
  },
});
