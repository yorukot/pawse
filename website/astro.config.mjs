import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://pawse.yorukot.me',
  output: 'static',
  integrations: [
    starlight({
      title: 'Pawse',
      description:
        'A private macOS focus timer that waits for a natural stopping point before starting your break.',
      favicon: '/assets/favicon.png',
      logo: {
        src: './public/assets/pawse-logo.webp',
        alt: '',
      },
      customCss: ['./src/styles/custom.css'],
      editLink: {
        baseUrl: 'https://github.com/yorukot/pawse/edit/main/website/',
      },
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
      sidebar: [
        { label: 'Home', link: '/' },
        { label: 'Download', link: '/download/' },
        {
          label: 'Start Here',
          items: [
            { slug: 'docs' },
            { slug: 'docs/install' },
            { slug: 'docs/quick-start' },
          ],
        },
        {
          label: 'How Pawse Works',
          items: [
            { slug: 'docs/how-pawse-works/focus-cycle' },
            { slug: 'docs/how-pawse-works/natural-breaks' },
            { slug: 'docs/how-pawse-works/discreet-mode' },
            { slug: 'docs/how-pawse-works/end-break-early' },
          ],
        },
        {
          label: 'Customize',
          items: [
            { slug: 'docs/customize/timers-and-cycle' },
            { slug: 'docs/customize/break-behavior' },
            { slug: 'docs/customize/sounds-and-appearance' },
            { slug: 'docs/customize/general-and-language' },
          ],
        },
        {
          label: 'Data',
          items: [
            { slug: 'docs/data/analytics' },
            { slug: 'docs/data/privacy' },
          ],
        },
        {
          label: 'Help',
          items: [
            { slug: 'docs/help/troubleshooting' },
            { slug: 'docs/help/faq' },
          ],
        },
      ],
      components: {
        ThemeProvider: './src/components/DarkThemeProvider.astro',
        ThemeSelect: './src/components/Empty.astro',
        SocialIcons: './src/components/HeaderLinks.astro',
        PageTitle: './src/components/ConditionalPageTitle.astro',
        Footer: './src/components/Footer.astro',
      },
      head: [
        { tag: 'meta', attrs: { name: 'author', content: 'Yorukot' } },
        { tag: 'meta', attrs: { name: 'theme-color', content: '#0D1219' } },
        {
          tag: 'meta',
          attrs: {
            property: 'og:image',
            content: 'https://pawse.yorukot.me/assets/pawse-hero.webp',
          },
        },
        {
          tag: 'meta',
          attrs: { name: 'twitter:card', content: 'summary_large_image' },
        },
      ],
    }),
  ],
});
