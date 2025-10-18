import { NextResponse } from "next/server"

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const rnc = searchParams.get('rnc')
    const name = searchParams.get('name')
    const page = searchParams.get('page') || '1'
    const limit = searchParams.get('limit') || '10'

    if (rnc) {
      // Lookup by RNC
      const response = await fetch(`https://rnc-contributors.vercel.app/api/contributors/rnc/${rnc}`)
      
      if (!response.ok) {
        if (response.status === 400) {
          return NextResponse.json({ 
            success: false, 
            error: "Contributor not found" 
          }, { status: 404 })
        }
        throw new Error("External API error")
      }

      const data = await response.json()
      
      return NextResponse.json({
        success: true,
        data: {
          rnc: data.rnc,
          social_reason: data.social_reason,
          commercial_name: data.commercial_name,
          economic_activity: data.economic_activity,
          status: data.status,
          payment_type: data.payment_type
        }
      })
    } else if (name) {
      // Lookup by business name
      const response = await fetch(`https://rnc-contributors.vercel.app/api/contributors/name/?page=${page}&limit=${limit}&name=${encodeURIComponent(name)}`)
      
      if (!response.ok) {
        if (response.status === 400) {
          return NextResponse.json({ 
            success: false, 
            error: "Name is required" 
          }, { status: 400 })
        }
        if (response.status === 404) {
          return NextResponse.json({ 
            success: false, 
            error: "Contributor not found" 
          }, { status: 404 })
        }
        throw new Error("External API error")
      }

      const data = await response.json()
      
      return NextResponse.json({
        success: true,
        data: {
          total: data.total,
          totalPages: data.totalPages,
          currentPage: data.currentPage,
          prevPage: data.prevPage,
          nextPage: data.nextPage,
          results: data.data.map((contributor: any) => ({
            rnc: contributor.rnc,
            social_reason: contributor.social_reason,
            commercial_name: contributor.commercial_name,
            economic_activity: contributor.economic_activity,
            status: contributor.status,
            payment_type: contributor.payment_type
          }))
        }
      })
    } else {
      return NextResponse.json({ 
        success: false, 
        error: "Either RNC or name parameter is required" 
      }, { status: 400 })
    }
  } catch (error) {
    console.error("[RNC Lookup] Error:", error)
    return NextResponse.json(
      {
        success: false,
        error: "Error al consultar el servicio de RNC",
      },
      { status: 500 },
    )
  }
}
