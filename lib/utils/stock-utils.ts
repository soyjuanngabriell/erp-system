import { createClient } from "@/lib/supabase/server"

export interface Product {
  id: string
  name: string
  sku: string
  price: number
  cost: number
  stock: number
  min_stock: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface LowStockProduct extends Product {
  stock_status: 'critical' | 'low' | 'ok'
  days_remaining?: number
}

/**
 * Get all active products from the database
 */
export async function getAllActiveProducts(): Promise<Product[]> {
  const supabase = await createClient()
  
  const { data: products, error } = await supabase
    .from("products")
    .select("*")
    .eq("is_active", true)
    .order("name")

  if (error) {
    console.error("Error fetching products:", error)
    return []
  }

  return products || []
}

/**
 * Filter products with low stock based on their min_stock threshold
 */
export function getLowStockProducts(products: Product[]): LowStockProduct[] {
  return products
    .filter(product => product.stock <= product.min_stock)
    .map(product => ({
      ...product,
      stock_status: product.stock === 0 ? 'critical' : 
                   product.stock <= (product.min_stock * 0.5) ? 'critical' : 'low'
    }))
    .sort((a, b) => a.stock - b.stock) // Sort by stock level (lowest first)
}

/**
 * Get stock statistics for dashboard
 */
export function getStockStatistics(products: Product[]) {
  const lowStockProducts = getLowStockProducts(products)
  const criticalStock = lowStockProducts.filter(p => p.stock_status === 'critical')
  const lowStock = lowStockProducts.filter(p => p.stock_status === 'low')
  
  return {
    totalProducts: products.length,
    lowStockCount: lowStockProducts.length,
    criticalStockCount: criticalStock.length,
    lowStockProducts,
    criticalStockProducts: criticalStock
  }
}

/**
 * Get business configuration for low stock threshold
 */
export async function getBusinessConfig() {
  const supabase = await createClient()
  
  const { data: config, error } = await supabase
    .from("business_config")
    .select("*")
    .limit(1)
    .single()

  if (error) {
    console.error("Error fetching business config:", error)
    return null
  }

  return config
}
