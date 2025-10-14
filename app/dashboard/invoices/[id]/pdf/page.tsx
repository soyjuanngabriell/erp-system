import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import { notFound } from "next/navigation"

export default async function InvoicePDFPage({ 
  params 
}: { 
  params: Promise<{ id: string }> 
}) {
  const { id } = await params
  const supabase = await createClient()

  // Verify invoice exists
  const { data: invoice } = await supabase
    .from("invoices")
    .select("id")
    .eq("id", id)
    .single()

  if (!invoice) {
    notFound()
  }

  // Redirect to API route for PDF generation
  redirect(`/api/invoices/${id}/pdf`)
}
