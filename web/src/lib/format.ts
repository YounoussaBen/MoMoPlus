export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export const ID_TYPE_LABEL: Record<string, string> = {
  national_id: "Ghana Card",
  passport: "Passport",
  drivers_license: "Driver's License",
};

export function formatIdType(idType: string): string {
  return ID_TYPE_LABEL[idType] ?? idType;
}
