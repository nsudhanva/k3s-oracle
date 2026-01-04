import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: 'K3s on OCI Always Free',
      social: {
        github: 'https://github.com/nsudhanva/k3s-oracle',
      },
      sidebar: [
        {
          label: 'Setup',
          items: [
            { label: 'Initial Setup', link: '/setup/initial-setup' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Networking & NAT', link: '/networking/nat-and-firewall' },
            { label: 'GitOps & Argo CD', link: '/gitops/app-of-apps' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Troubleshooting', link: '/troubleshooting' },
          ],
        },
      ],
    }),
  ],
});