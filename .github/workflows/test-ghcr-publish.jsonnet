// Test workflow to verify GHCR publishing works in fork
// This is a simplified version that only publishes to GHCR (no Docker Hub, no ECR, no Depot)

local actions = import 'libs/actions.libsonnet';
local gha = import 'libs/gha.libsonnet';

{
  name: 'Test GHCR Publishing',
  on: {
    workflow_dispatch: {},
    push: {
      tags: ['test-*', 'v*-test'],
    },
  },
  jobs: {
    'test-ghcr-push': {
      'runs-on': 'ubuntu-latest',
      permissions: {
        contents: 'read',
        packages: 'write',  // Required for pushing to GHCR
      },
      steps: actions.checkout_with_submodules() + [
        // Only login to GHCR for this test
        actions.ghcr_login_step,
        {
          uses: 'docker/setup-buildx-action@v3',
        },
        {
          id: 'meta',
          name: 'Set tags and labels',
          uses: 'docker/metadata-action@v5',
          with: {
            images: 'ghcr.io/${{ github.repository }}',  // Uses fork's repo name
            flavor: 'latest=false',
            tags: |||
              type=ref,event=branch
              type=ref,event=tag
              type=sha,prefix=sha-
            |||,
          },
        },
        {
          id: 'build',
          name: 'Build and push to GHCR',
          uses: 'docker/build-push-action@v6',
          with: {
            context: '.',
            file: 'Dockerfile',
            target: 'semgrep-cli',
            platforms: 'linux/amd64',
            push: true,
            tags: '${{ steps.meta.outputs.tags }}',
            labels: '${{ steps.meta.outputs.labels }}',
            'cache-from': 'type=gha',
            'cache-to': 'type=gha,mode=max',
          },
        },
        {
          name: 'Output image details',
          run: |||
            echo "### 🎉 Image published successfully!" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "**Digest:** ${{ steps.build.outputs.digest }}" >> $GITHUB_STEP_SUMMARY
            echo "" >> $GITHUB_STEP_SUMMARY
            echo "**Pull command:**" >> $GITHUB_STEP_SUMMARY
            echo '```' >> $GITHUB_STEP_SUMMARY
            echo "docker pull ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}" >> $GITHUB_STEP_SUMMARY
            echo '```' >> $GITHUB_STEP_SUMMARY
          |||,
        },
      ],
    },
  },
}
