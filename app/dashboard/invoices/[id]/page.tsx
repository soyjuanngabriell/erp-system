import { createClient } from "@/lib/supabase/server"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { notFound } from "next/navigation"
import { PrintButton } from "@/components/pdf-generator"

export default async function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  const { data: invoice } = await supabase
    .from("invoices")
    .select(
      `
      *,
      invoice_items (*)
    `,
    )
    .eq("id", id)
    .single()

  if (!invoice) {
    notFound()
  }

  const { data: businessConfig } = await supabase.from("business_config").select("*").single()

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/invoices">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-3xl font-bold">Factura {invoice.invoice_number}</h1>
            <p className="text-muted-foreground">Detalles de la factura</p>
          </div>
        </div>
        <PrintButton invoiceId={id} invoiceNumber={invoice.invoice_number} />
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Información del Negocio</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm text-muted-foreground">Nombre</p>
              <p className="font-medium">{businessConfig?.business_name}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">RNC</p>
              <p className="font-medium">{businessConfig?.rnc}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Dirección</p>
              <p className="font-medium">{businessConfig?.address}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Teléfono</p>
              <p className="font-medium">{businessConfig?.phone}</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Información del Cliente</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm text-muted-foreground">Nombre</p>
              <p className="font-medium">{invoice.customer_name}</p>
            </div>
            {invoice.customer_rnc && (
              <div>
                <p className="text-sm text-muted-foreground">RNC/Cédula</p>
                <p className="font-medium">{invoice.customer_rnc}</p>
              </div>
            )}
            <div>
              <p className="text-sm text-muted-foreground">Tipo de Factura</p>
              <p className="font-medium">
                {invoice.invoice_type === 'BASICA' && 'Básica'}
                {invoice.invoice_type === 'VALOR_FISCAL' && 'Valor Fiscal'}
                {invoice.invoice_type === 'VALOR_GUBERNAMENTAL' && 'Valor Gubernamental'}
              </p>
            </div>
            {invoice.ncf && (
              <div>
                <p className="text-sm text-muted-foreground">NCF</p>
                <p className="font-medium">{invoice.ncf}</p>
              </div>
            )}
            <div>
              <p className="text-sm text-muted-foreground">Método de Pago</p>
              <p className="font-medium">{invoice.payment_method}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Fecha</p>
              <p className="font-medium">{new Date(invoice.created_at).toLocaleDateString("es-DO")}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Productos</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Producto</TableHead>
                  <TableHead>SKU</TableHead>
                  <TableHead className="text-right">Cantidad</TableHead>
                  <TableHead className="text-right">Precio Unitario</TableHead>
                  <TableHead className="text-right">Subtotal</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {invoice.invoice_items.map((item: any) => (
                  <TableRow key={item.id}>
                    <TableCell>{item.product_name}</TableCell>
                    <TableCell>{item.product_sku}</TableCell>
                    <TableCell className="text-right">{item.quantity}</TableCell>
                    <TableCell className="text-right">RD$ {(item.unit_price || 0).toLocaleString()}</TableCell>
                    <TableCell className="text-right">RD$ {(item.subtotal || 0).toLocaleString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          <div className="mt-6 flex justify-end">
            <div className="w-64 space-y-2">
              <div className="flex justify-between">
                <span>Subtotal:</span>
                <span className="font-medium">RD$ {invoice.subtotal.toLocaleString()}</span>
              </div>
              <div className="flex justify-between">
                <span>ITBIS (18%):</span>
                <span className="font-medium">RD$ {invoice.tax.toLocaleString()}</span>
              </div>
              {invoice.discount > 0 && (
                <div className="flex justify-between">
                  <span>Descuento:</span>
                  <span className="font-medium">- RD$ {invoice.discount.toLocaleString()}</span>
                </div>
              )}
              <div className="flex justify-between border-t pt-2">
                <span className="font-bold">Total:</span>
                <span className="font-bold">RD$ {invoice.total.toLocaleString()}</span>
              </div>
            </div>
          </div>

          {invoice.notes && (
            <div className="mt-6">
              <p className="text-sm text-muted-foreground">Notas</p>
              <p className="mt-1">{invoice.notes}</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
