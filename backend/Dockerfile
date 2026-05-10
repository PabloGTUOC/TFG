FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

# Ensure the uploads directory exists
RUN mkdir -p uploads && chown -R node:node uploads

EXPOSE 3000
CMD ["npm", "start"]
