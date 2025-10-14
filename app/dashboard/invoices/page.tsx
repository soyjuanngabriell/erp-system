import { createClient } from "@/lib/supabase/server"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Plus } from "lucide-react"
import Link from "next/link"
import { InvoicesTable } from "@/components/invoices-table"

export default async function InvoicesPage() {
  const supabase = await createClient()

  const { data: invoices } = await supabase
    .from("invoices")
    .select(
      `
      *,
      invoice_items (*)
    `,
    )
    .order("created_at", { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Facturación</h1>
          <p className="text-muted-foreground">Gestiona las facturas y punto de venta</p>
        </div>
        <Button asChild>
          <Link href="/dashboard/invoices/new">
            <Plus className="mr-2 h-4 w-4" />
            Nueva Factura
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Lista de Facturas</CardTitle>
        </CardHeader>
        <CardContent>
          <InvoicesTable invoices={invoices || []} />
        </CardContent>
      </Card>
    </div>
  )
}
