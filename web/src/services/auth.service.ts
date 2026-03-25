import { isAxiosError } from "axios";
import { AuthRepository } from "@/repositories/auth.repository";

export class AuthService {
  constructor(private readonly authRepository: AuthRepository) {}

  async login(email: string, password: string) {
    try {
      return await this.authRepository.login(email, password);
    } catch (error) {
      if (isAxiosError(error)) {
        const detail =
          typeof error.response?.data?.detail === "string"
            ? error.response.data.detail
            : "Invalid credentials.";

        throw new Error(detail);
      }

      throw error;
    }
  }
}
