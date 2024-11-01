import {defineConfig} from 'vitepress';

export default defineConfig({
  lang: 'en-US',
  title: 'pog 🤯',
  description: 'pog documentation',
  themeConfig: {
    nav: [
      {text: 'Home', link: '/'},
      {text: 'Getting Started', link: '/getting-started'},
      {text: 'Examples', link: '/basic-examples'},
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          {text: 'Getting Started', link: '/getting-started'},
          {text: 'What is pog?', link: '/what-is-pog'},
        ],
      },
      {
        text: 'Examples',
        items: [
          {text: 'Basic Example', link: '/basic-examples'},
          {text: 'More Examples', link: '/more-examples'},
          {text: 'Full Spec', link: '/specs'},
        ],
      },
    ],
    socialLinks: [{icon: 'github', link: 'https://github.com/jpetrucciani/pog'}],
  },
  cleanUrls: true,
  sitemap: {
    hostname: 'https://pog.gemologic.dev',
    lastmodDateOnly: false,
  },
});
