import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_')

  return {
    plugins: [
      react(),
      {
        name: 'inject-gtm',
        transformIndexHtml(html) {
          const gtmId = env.VITE_GTM_ID
          if (!gtmId) return html.replace('<!-- GTM_PLACEHOLDER -->', '')
          return html.replace(
            '<!-- GTM_PLACEHOLDER -->',
            `<script async src="https://www.googletagmanager.com/gtag/js?id=${gtmId}"></script>\n    <script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}gtag('js',new Date());gtag('config','${gtmId}')</script>`
          )
        },
      },
    ],
  }
})
