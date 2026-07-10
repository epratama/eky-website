import { useState, useRef, useEffect } from 'react'
import { Send, CheckCircle, AlertCircle, Loader2 } from 'lucide-react'
import SectionTitle from './SectionTitle'

const LAMBDA_URL = import.meta.env.VITE_LAMBDA_URL || ''

export default function ContactForm() {
  const [form, setForm] = useState({ name: '', email: '', mobile: '', message: '' })
  const [errors, setErrors] = useState({})
  const [status, setStatus] = useState('idle')
  const captchaRef = useRef(null)
  const captchaWidgetId = useRef(null)
  const formRef = useRef(form)
  formRef.current = form

  useEffect(() => {
    const script = document.createElement('script')
    script.src = 'https://js.hcaptcha.com/1/api.js?render=explicit&onload=onHCaptchaLoad'
    script.async = true
    script.defer = true

    window.onHCaptchaLoad = () => {
      if (captchaRef.current && window.hcaptcha) {
        captchaWidgetId.current = window.hcaptcha.render(captchaRef.current, {
          sitekey: import.meta.env.VITE_HCAPTCHA_SITEKEY,
          size: 'invisible',
          callback: (token) => submitForm(token),
          'error-callback': () => {
            setStatus('error')
            setErrors({ form: 'Captcha verification failed. Please try again.' })
          },
        })
      }
    }

    document.head.appendChild(script)
    return () => {
      if (script.parentNode) script.parentNode.removeChild(script)
      delete window.onHCaptchaLoad
    }
  }, [])

  const validate = () => {
    const errs = {}
    if (!form.name.trim()) errs.name = 'Name is required'
    if (!form.email.trim()) {
      errs.email = 'Email is required'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
      errs.email = 'Invalid email format'
    }
    if (!form.message.trim()) errs.message = 'Message is required'
    if (form.mobile.trim() && !/^[+]?[\d\s\-().]{6,20}$/.test(form.mobile.trim())) errs.mobile = 'Enter a valid phone number'
    return errs
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    const errs = validate()
    setErrors(errs)
    if (Object.keys(errs).length > 0) return

    setStatus('loading')
    if (window.hcaptcha && captchaWidgetId.current !== null) {
      window.hcaptcha.execute(captchaWidgetId.current)
    } else {
      submitForm()
    }
  }

  const submitForm = async (token) => {
    const currentForm = formRef.current
    try {
      const res = await fetch(LAMBDA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: currentForm.name,
          email: currentForm.email,
          mobile: currentForm.mobile || undefined,
          message: currentForm.message,
          hcaptcha_token: import.meta.env.DEV ? (token || 'dev-bypass') : token,
        }),
      })

      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        throw new Error(body.error || 'Submission failed')
      }

      setStatus('success')
    } catch (err) {
      setStatus('error')
      console.error('Contact form submission failed:', err)
      setErrors({ form: 'Something went wrong. Please try again.' })
    } finally {
      if (window.hcaptcha && captchaWidgetId.current !== null) {
        window.hcaptcha.reset(captchaWidgetId.current)
      }
    }
  }

  const handleChange = (field) => (e) => {
    setForm({ ...form, [field]: e.target.value })
    if (errors[field]) setErrors({ ...errors, [field]: undefined, form: undefined })
  }

  const inputClass = (field) =>
    `w-full border-[3px] border-brutal-primary bg-white px-4 py-3 font-body text-sm font-medium text-brutal-primary placeholder:text-brutal-muted placeholder:font-normal focus:outline-none focus:border-brutal-accent ${
      errors[field] ? 'border-red-600' : ''
    }`

  if (status === 'success') {
    return (
      <section id="contact" className="py-20 px-6 bg-white border-t-[3px] border-brutal-primary">
        <div className="mx-auto max-w-xl text-center">
          <CheckCircle size={48} className="mx-auto text-brutal-accent mb-4" />
          <h2 className="font-heading text-2xl font-extrabold text-brutal-primary mb-2">
            Message Sent
          </h2>
          <p className="font-body text-brutal-muted">
            Thanks for reaching out. I'll get back to you soon.
          </p>
        </div>
      </section>
    )
  }

  return (
    <section id="contact" className="py-20 px-6 bg-white border-t-[3px] border-brutal-primary">
      <div className="mx-auto max-w-xl">
        <SectionTitle number="06" title="Get in Touch" />

        <form onSubmit={handleSubmit} className="space-y-5" noValidate>
          <div>
            <label htmlFor="name" className="block font-heading text-sm font-extrabold text-brutal-primary mb-1.5">
              Name <span className="text-brutal-accent">*</span>
            </label>
            <input
              id="name"
              type="text"
              value={form.name}
              onChange={handleChange('name')}
              className={inputClass('name')}
              placeholder="Your name"
              autoComplete="name"
            />
            {errors.name && (
              <p className="mt-1 font-body text-xs font-semibold text-red-600">{errors.name}</p>
            )}
          </div>

          <div>
            <label htmlFor="email" className="block font-heading text-sm font-extrabold text-brutal-primary mb-1.5">
              Email <span className="text-brutal-accent">*</span>
            </label>
            <input
              id="email"
              type="email"
              value={form.email}
              onChange={handleChange('email')}
              className={inputClass('email')}
              placeholder="you@example.com"
              autoComplete="email"
            />
            {errors.email && (
              <p className="mt-1 font-body text-xs font-semibold text-red-600">{errors.email}</p>
            )}
          </div>

          <div>
            <label htmlFor="mobile" className="block font-heading text-sm font-extrabold text-brutal-primary mb-1.5">
              Mobile <span className="font-body text-xs text-brutal-muted">(optional)</span>
            </label>
            <input
              id="mobile"
              type="tel"
              pattern="[+]?[\d\s\-().]{6,20}"
              title="Enter a valid phone number (e.g. +61 400 000 000)"
              value={form.mobile}
              onChange={handleChange('mobile')}
              className={inputClass('mobile')}
              placeholder="+61 400 000 000"
              autoComplete="tel"
            />
          </div>

          <div>
            <label htmlFor="message" className="block font-heading text-sm font-extrabold text-brutal-primary mb-1.5">
              Message <span className="text-brutal-accent">*</span>
            </label>
            <textarea
              id="message"
              rows={5}
              value={form.message}
              onChange={handleChange('message')}
              className={`${inputClass('message')} resize-none`}
              placeholder="What would you like to discuss?"
            />
            {errors.message && (
              <p className="mt-1 font-body text-xs font-semibold text-red-600">{errors.message}</p>
            )}
          </div>

          <div ref={captchaRef} className="flex justify-center" />

          {errors.form && (
            <div className="flex items-center gap-2 bg-red-50 border-[2px] border-red-600 p-3">
              <AlertCircle size={16} className="text-red-600 flex-shrink-0" />
              <p className="font-body text-xs font-semibold text-red-600">{errors.form}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={status === 'loading'}
            className="w-full flex items-center justify-center gap-2 border-[3px] border-brutal-primary bg-brutal-primary text-brutal-bg py-3 font-heading text-sm font-extrabold hover:bg-brutal-bg hover:text-brutal-primary cursor-pointer transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {status === 'loading' ? (
              <>
                <Loader2 size={18} className="animate-spin" />
                Sending...
              </>
            ) : (
              <>
                <Send size={18} />
                Send Message
              </>
            )}
          </button>
        </form>
      </div>
    </section>
  )
}
