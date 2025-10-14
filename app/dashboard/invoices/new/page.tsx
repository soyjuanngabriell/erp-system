import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { InvoiceForm } from "@/components/invoice-form"

export default async function NewInvoicePage() {
  const supabase = await createClient()

  const { data: products } = await supabase.from("products").select("*").eq("is_active", true).order("name")

  const { data: customers } = await supabase.from("customers").select("*").order("name")

  const { data: businessConfig } = await supabase.from("business_config").select("*").single()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Nueva Factura</h1>
        <p className="text-muted-foreground">Crea una nueva factura de venta</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Información de la Factura</CardTitle>
        </CardHeader>
        <CardContent>
          <InvoiceForm products={products || []} customers={customers || []} businessConfig={businessConfig} />
        </CardContent>
      </Card>
    </div>
  )
}
