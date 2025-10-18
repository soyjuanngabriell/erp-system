"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Plus, Trash2, Search, Save } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

interface Product {
  id: string
  name: string
  sku: string
  price: number
  stock: number
}

interface Customer {
  id: string
  name: string
  rnc_cedula: string | null
}

interface BusinessConfig {
  business_name: string
  rnc: string
  fiscal_sequence: number
  governmental_sequence: number
}

interface InvoiceItem {
  product_id: string
  product_name: string
  product_sku: string
  quantity: number
  unit_price: number
  subtotal: number
}

interface InvoiceFormProps {
  products: Product[]
  customers: Customer[]
  businessConfig: BusinessConfig | null
}

interface RncSearchResult {
  rnc: string
  social_reason: string
  commercial_name: string
  economic_activity: string
  status: string
  payment_type: string
}


export function InvoiceForm({ products, customers, businessConfig }: InvoiceFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  const [customerId, setCustomerId] = useState("")
  const [customerName, setCustomerName] = useState("")
  const [customerRnc, setCustomerRnc] = useState("")
  const [customerEmail, setCustomerEmail] = useState("")
  const [customerPhone, setCustomerPhone] = useState("")
  const [paymentMethod, setPaymentMethod] = useState("Efectivo")
  const [notes, setNotes] = useState("")
  const [invoiceType, setInvoiceType] = useState<"BASICA" | "VALOR_FISCAL" | "VALOR_GUBERNAMENTAL">("BASICA")
  const [items, setItems] = useState<InvoiceItem[]>([])

  const [selectedProduct, setSelectedProduct] = useState("")
  const [quantity, setQuantity] = useState(1)

  // DGII RNC lookup state
  const [rncLookup, setRncLookup] = useState("")
  const [isLookingUp, setIsLookingUp] = useState(false)
  
  // Enhanced RNC lookup state
  const [selectedSearchResult, setSelectedSearchResult] = useState<RncSearchResult | null>(null)
  const [isSavingCustomer, setIsSavingCustomer] = useState(false)

  const handleCustomerChange = (value: string) => {
    setCustomerId(value)
    const customer = customers.find((c) => c.id === value)
    if (customer) {
      setCustomerName(customer.name)
      setCustomerRnc(customer.rnc_cedula || "")
      setCustomerEmail(customer.email || "")
      setCustomerPhone(customer.phone || "")
    }
  }

  const handleRncLookup = async () => {
    if (!rncLookup) return

    setIsLookingUp(true)
    try {
      const response = await fetch(`/api/rnc-lookup?rnc=${encodeURIComponent(rncLookup)}`)
      const data = await response.json()

      if (data.success && data.data) {
        setSelectedSearchResult(data.data)
        setCustomerName(data.data.social_reason || data.data.commercial_name)
        setCustomerRnc(data.data.rnc)
        toast({
          title: "RNC encontrado",
          description: `Contribuyente: ${data.data.social_reason || data.data.commercial_name}`,
        })
      } else {
        toast({
          title: "RNC no encontrado",
          description: "No se encontró información para este RNC",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al consultar el RNC",
        variant: "destructive",
      })
    } finally {
      setIsLookingUp(false)
    }
  }

  const handleSaveCustomer = async () => {
    if (!selectedSearchResult) return

    setIsSavingCustomer(true)
    try {
      const response = await fetch("/api/customers", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: selectedSearchResult.social_reason || selectedSearchResult.commercial_name,
          rnc_cedula: selectedSearchResult.rnc,
          email: "",
          phone: "",
          address: ""
        })
      })

      const data = await response.json()

      if (data.success) {
        toast({
          title: "Cliente guardado",
          description: "El cliente ha sido guardado exitosamente",
        })
        // Refresh the page to update the customers list
        router.refresh()
      } else {
        toast({
          title: "Error al guardar",
          description: data.error || "No se pudo guardar el cliente",
          variant: "destructive",
        })
      }
    } catch (error) {
      toast({
        title: "Error",
        description: "Error al guardar el cliente",
        variant: "destructive",
      })
    } finally {
      setIsSavingCustomer(false)
    }
  }

  const handleAddItem = () => {
    const product = products.find((p) => p.id === selectedProduct)
    if (!product) return

    if (quantity > product.stock) {
      toast({
        title: "Error",
        description: "No hay suficiente stock disponible",
        variant: "destructive",
      })
      return
    }

    const existingItem = items.find((item) => item.product_id === product.id)
    if (existingItem) {
      setItems(
        items.map((item) =>
          item.product_id === product.id
            ? {
                ...item,
                quantity: item.quantity + quantity,
                subtotal: (item.quantity + quantity) * item.unit_price,
              }
            : item,
        ),
      )
    } else {
      setItems([
        ...items,
        {
          product_id: product.id,
          product_name: product.name,
          product_sku: product.sku,
          quantity,
          unit_price: product.price,
          subtotal: quantity * product.price,
        },
      ])
    }

    setSelectedProduct("")
    setQuantity(1)
  }

  const handleRemoveItem = (productId: string) => {
    setItems(items.filter((item) => item.product_id !== productId))
  }

  const subtotal = items.reduce((sum, item) => sum + item.subtotal, 0)
  const tax = (invoiceType === "VALOR_FISCAL" || invoiceType === "VALOR_GUBERNAMENTAL") ? subtotal * 0.18 : 0 // Solo ITBIS para facturas fiscales y gubernamentales
  const total = subtotal + tax

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) throw new Error("No autenticado")

      if (items.length === 0) {
        throw new Error("Debe agregar al menos un producto")
      }

      // Get next invoice number by type from database function
      const { data: invoiceNumberData, error: invoiceNumberError } = await supabase.rpc("get_next_invoice_number", {
        p_invoice_type: invoiceType
      })

      if (invoiceNumberError) throw invoiceNumberError

      const invoiceNumber = invoiceNumberData

      // Generate NCF for fiscal invoices
      let ncf = null
      if (invoiceType === "VALOR_FISCAL" || invoiceType === "VALOR_GUBERNAMENTAL") {
        const { data: ncfData, error: ncfError } = await supabase.rpc("generate_ncf", {
          p_invoice_type: invoiceType,
          p_sequence: parseInt(invoiceNumber.slice(-4)) // Extract sequence from invoice number
        })
        if (ncfError) throw ncfError
        ncf = ncfData
      }

      // Create invoice
      const { data: invoice, error: invoiceError } = await supabase
        .from("invoices")
        .insert({
          invoice_number: invoiceNumber,
          invoice_type: invoiceType,
          ncf: ncf,
          customer_name: customerName,
          customer_rnc: customerRnc || null,
          customer_email: customerEmail || null,
          customer_phone: customerPhone || null,
          subtotal,
          tax,
          discount: 0,
          total,
          payment_method: paymentMethod,
          notes: notes || null,
          created_by: user.id,
        })
        .select()
        .single()

      if (invoiceError) throw invoiceError

      // Create invoice items
      const { error: itemsError } = await supabase.from("invoice_items").insert(
        items.map((item) => ({
          invoice_id: invoice.id,
          product_id: item.product_id,
          product_name: item.product_name,
          product_sku: item.product_sku,
          quantity: item.quantity,
          unit_price: item.unit_price,
          subtotal: item.subtotal,
        })),
      )

      if (itemsError) throw itemsError

      // Update stock for each product
      for (const item of items) {
        console.log('Updating stock for item:', item.product_name, 'quantity:', item.quantity)
        
        const { data: stockResult, error: stockError } = await supabase.rpc("update_product_stock", {
          p_product_id: item.product_id,
          p_quantity: item.quantity,
          p_movement_type: "SALIDA",
          p_reason: `Factura ${invoiceNumber}`,
          p_reference_id: invoice.id,
          p_reference_type: "invoice",
          p_user_id: user.id,
        })

        console.log('Stock update result:', stockResult, 'error:', stockError)

        if (stockError) throw stockError

        if (!stockResult || !stockResult.success) {
          const errorMsg = stockResult?.error || "Error desconocido al actualizar stock"
          throw new Error(`Error al actualizar stock para ${item.product_name}: ${errorMsg}`)
        }
      }

      toast({
        title: "Factura creada",
        description: `La factura ${invoiceNumber} ha sido creada exitosamente`,
      })

      router.push(`/dashboard/invoices/${invoice.id}`)
      router.refresh()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Error al crear la factura",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor="customer">Cliente Existente</Label>
          <Select value={customerId} onValueChange={handleCustomerChange}>
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar cliente" />
            </SelectTrigger>
            <SelectContent>
              {customers.map((customer) => (
                <SelectItem key={customer.id} value={customer.id}>
                  {customer.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="rncLookup">Buscar por RNC</Label>
          <div className="flex gap-2">
            <Input
              id="rncLookup"
              value={rncLookup}
              onChange={(e) => setRncLookup(e.target.value)}
              placeholder="000-0000000-0"
            />
            <Button type="button" onClick={handleRncLookup} disabled={isLookingUp}>
              <Search className="h-4 w-4" />
            </Button>
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="customerName">Nombre del Cliente</Label>
          <Input
            id="customerName"
            value={customerName}
            onChange={(e) => setCustomerName(e.target.value)}
            placeholder="Nombre del cliente"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="customerRnc">RNC/Cédula</Label>
          <Input
            id="customerRnc"
            value={customerRnc}
            onChange={(e) => setCustomerRnc(e.target.value)}
            placeholder="RNC o Cédula"
          />
        </div>

        {selectedSearchResult && (
          <div className="col-span-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Información del Contribuyente</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="font-medium">RNC:</span> {selectedSearchResult.rnc}
                  </div>
                  <div>
                    <span className="font-medium">Estado:</span> {selectedSearchResult.status}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Razón Social:</span> {selectedSearchResult.social_reason}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Nombre Comercial:</span> {selectedSearchResult.commercial_name}
                  </div>
                  <div className="col-span-2">
                    <span className="font-medium">Actividad Económica:</span> {selectedSearchResult.economic_activity}
                  </div>
                  <div>
                    <span className="font-medium">Tipo de Pago:</span> {selectedSearchResult.payment_type}
                  </div>
                </div>
                <div className="flex gap-2 pt-2">
                  <Button 
                    type="button" 
                    size="sm" 
                    onClick={handleSaveCustomer}
                    disabled={isSavingCustomer}
                  >
                    <Save className="h-4 w-4 mr-2" />
                    {isSavingCustomer ? "Guardando..." : "Guardar Cliente"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        <div className="space-y-2">
          <Label htmlFor="paymentMethod">Método de Pago</Label>
          <Select value={paymentMethod} onValueChange={setPaymentMethod} required>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Efectivo">Efectivo</SelectItem>
              <SelectItem value="Tarjeta">Tarjeta</SelectItem>
              <SelectItem value="Transferencia">Transferencia</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="invoiceType">Tipo de Factura</Label>
          <Select value={invoiceType} onValueChange={(value: "BASICA" | "VALOR_FISCAL" | "VALOR_GUBERNAMENTAL") => setInvoiceType(value)} required>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="BASICA">Básica (Sin valor fiscal)</SelectItem>
              <SelectItem value="VALOR_FISCAL">Valor Fiscal (B0100000XXXX)</SelectItem>
              <SelectItem value="VALOR_GUBERNAMENTAL">Valor Gubernamental (B1500000XXXX)</SelectItem>
            </SelectContent>
          </Select>
          <p className="text-sm text-muted-foreground">
            {invoiceType === "BASICA" && "Factura sin valor fiscal para uso interno"}
            {invoiceType === "VALOR_FISCAL" && "Factura con valor fiscal para contribuyentes"}
            {invoiceType === "VALOR_GUBERNAMENTAL" && "Factura con valor gubernamental para entidades públicas"}
          </p>
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="notes">Notas</Label>
        <Textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Notas adicionales" />
      </div>

      <div className="space-y-4">
        <h3 className="text-lg font-semibold">Productos</h3>

        <div className="flex gap-4">
          <div className="flex-1">
            <Select value={selectedProduct} onValueChange={setSelectedProduct}>
              <SelectTrigger>
                <SelectValue placeholder="Seleccionar producto" />
              </SelectTrigger>
              <SelectContent>
                {products.map((product) => (
                  <SelectItem key={product.id} value={product.id}>
                    {product.name} - RD$ {product.price.toLocaleString()} (Stock: {product.stock})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <Input
            type="number"
            min="1"
            value={quantity}
            onChange={(e) => setQuantity(Number.parseInt(e.target.value) || 1)}
            className="w-24"
            placeholder="Cant."
          />

          <Button type="button" onClick={handleAddItem} disabled={!selectedProduct}>
            <Plus className="h-4 w-4" />
          </Button>
        </div>

        {items.length > 0 && (
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Producto</TableHead>
                  <TableHead>SKU</TableHead>
                  <TableHead className="text-right">Cantidad</TableHead>
                  <TableHead className="text-right">Precio</TableHead>
                  <TableHead className="text-right">Subtotal</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((item) => (
                  <TableRow key={item.product_id}>
                    <TableCell>{item.product_name}</TableCell>
                    <TableCell>{item.product_sku}</TableCell>
                    <TableCell className="text-right">{item.quantity}</TableCell>
                    <TableCell className="text-right">RD$ {(item.unit_price || 0).toLocaleString()}</TableCell>
                    <TableCell className="text-right">RD$ {(item.subtotal || 0).toLocaleString()}</TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => handleRemoveItem(item.product_id)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}

        <div className="flex justify-end">
          <div className="w-64 space-y-2">
            <div className="flex justify-between">
              <span>Subtotal:</span>
              <span className="font-medium">RD$ {subtotal.toLocaleString()}</span>
            </div>
            {(invoiceType === "VALOR_FISCAL" || invoiceType === "VALOR_GUBERNAMENTAL") && (
              <div className="flex justify-between">
                <span>ITBIS (18%):</span>
                <span className="font-medium">RD$ {tax.toLocaleString()}</span>
              </div>
            )}
            <div className="flex justify-between border-t pt-2">
              <span className="font-bold">Total:</span>
              <span className="font-bold">RD$ {total.toLocaleString()}</span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-4">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          Cancelar
        </Button>
        <Button type="submit" disabled={isLoading || items.length === 0}>
          {isLoading ? "Creando..." : "Crear Factura"}
        </Button>
      </div>
    </form>
  )
}
