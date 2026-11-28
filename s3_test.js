import { S3Client, CreateBucketCommand, PutObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({
  endpoint: "http://localhost:4566",
  region: "us-east-1",
  forcePathStyle: true,                       
  credentials: { accessKeyId: "test", secretAccessKey: "test" },
});

await s3.send(new CreateBucketCommand({ Bucket: "test-bucket" }));
await s3.send(new PutObjectCommand({
  Bucket: "test-bucket",
  Key: "hello.txt",
  Body: "hello from localstack",
}));