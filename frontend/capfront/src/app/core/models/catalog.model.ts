// File purpose: Defines Angular TypeScript models for catalog model.
export interface ProductNutritionDto {
  calories: number | null;
  proteinG: number | null;
  carbsG: number | null;
  fatG: number | null;
  servingSize: string | null;
}

export interface SupermarketDto {
  id: number;
  name: string;
}

export interface ProductSummaryDto {
  id: number;
  name: string;
  brand: string | null;
  barcode: string | null;
  category: string;
  nutrition: ProductNutritionDto | null;
  bestPrice: number | null;
  bestPriceSupermarket: string | null;
  currency: string | null;
}

export interface ProductPriceDto {
  supermarketId: number;
  supermarketName: string;
  price: number;
  currency: string;
  observedAt: string;
}

export interface ProductPriceHistoryPointDto {
  supermarketId: number;
  supermarketName: string;
  price: number;
  currency: string;
  observedAt: string;
}

export interface ProductAvailabilityDto {
  supermarketId: number;
  supermarketName: string;
  available: boolean;
  observedAt: string;
}

export interface ProductDetailDto {
  id: number;
  name: string;
  brand: string | null;
  barcode: string | null;
  imageUrl: string | null;
  category: string;
  nutrition: ProductNutritionDto | null;
  prices: ProductPriceDto[];
  priceHistory: ProductPriceHistoryPointDto[];
  unavailableMarkets: ProductAvailabilityDto[];
}
