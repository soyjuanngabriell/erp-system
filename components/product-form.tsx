"use client"

import type React from "react"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { createClient } from "@/lib/supabase/client"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { useToast } from "@/hooks/use-toast"

interface ProductFormProps {
  product?: {
    id: string
    name: string
    description: string | null
    sku: string
    price: number
    cost: number
    stock: number
    min_stock: number
    category: string | null
    is_active: boolean
  }
}

export function ProductForm({ product }: ProductFormProps) {
  const router = useRouter()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)

  const [name, setName] = useState(product?.name || "")
  const [description, setDescription] = useState(product?.description || "")
  const [sku, setSku] = useState(product?.sku || "")
  const [price, setPrice] = useState(product?.price || 0)
  const [cost, setCost] = useState(product?.cost || 0)
  const [stock, setStock] = useState(product?.stock || 0)
  const [minStock, setMinStock] = useState(product?.min_stock || 10)
  const [category, setCategory] = useState(product?.category || "")
  const [isActive, setIsActive] = useState(product?.is_active ?? true)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const supabase = createClient()

      if (product) {
        // Update existing product
        const { error } = await supabase
          .from("products")
          .update({
            name,
            description: description || null,
            sku,
            price,
            cost,
            stock,
            min_stock: minStock,
            category: category || null,
            is_active: isActive,
          })
          .eq("id", product.id)

        if (error) throw error

        toast({
          title: "Producto actualizado",
          description: "El producto ha sido actualizado exitosamente",
        })
      } else {
        // Create new product
        const { error } = await supabase.from("products").insert({
          name,
          description: description || null,
          sku,
          price,
          cost,
          stock,
          min_stock: minStock,
          category: category || null,
          is_active: isActive,
        })

        if (error) throw error

        toast({
          title: "Producto creado",
          description: "El producto ha sido creado exitosamente",
        })
      }

      router.push("/dashboard/inventory")
      router.refresh()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Error al guardar el producto",
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
          <Label htmlFor="name">Nombre del Producto</Label>
          <Input
            id="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Nombre del producto"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="sku">SKU</Label>
          <Input id="sku" value={sku} onChange={(e) => setSku(e.target.value)} placeholder="SKU-001" required />
        </div>

        <div className="space-y-2 md:col-span-2">
          <Label htmlFor="description">Descripción</Label>
          <Textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Descripción del producto"
            rows={3}
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="category">Categoría</Label>
          <Input id="category" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="Categoría" />
        </div>

        <div className="space-y-2">
          <Label htmlFor="cost">Costo (RD$)</Label>
          <Input
            id="cost"
            type="number"
            step="0.01"
            min="0"
            value={cost}
            onChange={(e) => setCost(Number.parseFloat(e.target.value) || 0)}
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="price">Precio de Venta (RD$)</Label>
          <Input
            id="price"
            type="number"
            step="0.01"
            min="0"
            value={price}
            onChange={(e) => setPrice(Number.parseFloat(e.target.value) || 0)}
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="stock">Stock Actual</Label>
          <Input
            id="stock"
            type="number"
            min="0"
            value={stock}
            onChange={(e) => setStock(Number.parseInt(e.target.value) || 0)}
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="minStock">Stock Mínimo</Label>
          <Input
            id="minStock"
            type="number"
            min="0"
            value={minStock}
            onChange={(e) => setMinStock(Number.parseInt(e.target.value) || 0)}
            required
          />
        </div>

        <div className="flex items-center space-x-2">
          <Switch id="isActive" checked={isActive} onCheckedChange={setIsActive} />
          <Label htmlFor="isActive">Producto Activo</Label>
        </div>
      </div>

      <div className="flex justify-end gap-4">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          Cancelar
        </Button>
        <Button type="submit" disabled={isLoading}>
          {isLoading ? "Guardando..." : product ? "Actualizar Producto" : "Crear Producto"}
        </Button>
      </div>
    </form>
  )
}
