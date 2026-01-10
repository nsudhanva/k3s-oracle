import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: 'K3s on OCI Always Free',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/nsudhanva/k3s-oracle' },
      ],
      sidebar: [
        {
          label: 'Getting Started',
          items: [
            { label: 'Prerequisites', link: '/getting-started/prerequisites' },
            { label: 'Installation', link: '/getting-started/installation' },
            { label: 'Configuration', link: '/getting-started/configuration' },
          ],
        },
        {
          label: 'Architecture',
          items: [
            { label: 'Overview', link: '/architecture/overview' },
            { label: 'Networking', link: '/architecture/networking' },
            { label: 'GitOps', link: '/architecture/gitops' },
          ],
        },
        {
          label: 'Operation',
          items: [
            { label: 'Accessing Cluster', link: '/operation/accessing-cluster' },
            { label: 'Deploying Apps', link: '/operation/deploying-apps' },
          ],
        },
        {
          label: 'Troubleshooting',
          items: [
            { label: 'Common Issues', link: '/troubleshooting/common-issues' },
          ],
        },
      ],
    }),
  ],
});