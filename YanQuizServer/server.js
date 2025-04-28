// server.js - Main server file
require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const multer = require("multer");
const pdf = require("pdf-parse");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const { OpenAI } = require("openai");

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization"
  );

  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }

  next();
});

app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const method = req.method;
  const url = req.originalUrl || req.url;
  const ip =
    req.ip || req.headers["x-forwarded-for"] || req.connection.remoteAddress;

  console.log(`[${timestamp}] ${method} ${url} - IP: ${ip}`);

  res.on("finish", () => {
    console.log(`[${timestamp}] ${method} ${url} - Status: ${res.statusCode}`);
  });

  next();
});

// Configure OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// MongoDB schemas
const userSchema = new mongoose.Schema({
  id: { type: String, default: () => uuidv4() },
  email: { type: String, required: true, unique: true },
  name: { type: String },
  password: { type: String, required: true },
});

const quizSchema = new mongoose.Schema({
  id: { type: String, default: () => uuidv4() },
  title: { type: String, required: true },
  userId: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  questions: [
    {
      id: { type: String, default: () => uuidv4() },
      questionText: { type: String, required: true },
      questionType: { type: String, required: true },
      options: [{ type: String }],
      correctAnswer: { type: String, required: true },
      explanation: { type: String },
    },
  ],
});

const User = mongoose.model("User", userSchema);
const Quiz = mongoose.model("Quiz", quizSchema);

// Authentication middleware
const authenticate = (req, res, next) => {
  try {
    const token = req.header("Authorization").replace("Bearer ", "");
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (error) {
    res.status(401).send({ error: "Authentication required" });
  }
};

app.get("/open-test", (req, res) => {
  res.json({
    message: "Open endpoint working correctly",
    clientIP:
      req.ip || req.headers["x-forwarded-for"] || req.connection.remoteAddress,
  });
});

app.get("/api/test", (req, res) => {
  res.json({ message: "Server is working correctly" });
});

// Authentication routes
app.post("/api/auth/register", async (req, res) => {
  try {
    const { email, password, name } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).send({ error: "Email already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({
      email,
      password: hashedPassword,
      name,
    });

    await user.save();

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);

    res.status(201).send({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    res.status(500).send({ error: "Server error" });
  }
});

app.post("/api/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).send({ error: "Invalid credentials" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).send({ error: "Invalid credentials" });
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);

    res.send({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    res.status(500).send({ error: "Server error" });
  }
});

// PDF upload and quiz generation
app.post(
  "/api/quizzes/generate",
  authenticate,
  upload.single("pdfFile"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).send({ error: "No PDF file uploaded" });
      }

      // Extract text from PDF
      const pdfData = await pdf(req.file.buffer);
      const pdfText = pdfData.text;

      // Generate quiz using OpenAI
      const response = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content:
              "You are an educational assistant that creates comprehensive quizzes based on PDF content. Create a quiz with a mix of multiple choice, fill-in-the-blank, and long answer questions.",
          },
          {
            role: "user",
            content: `Create a quiz for the following content from a PDF: ${pdfText.substring(
              0,
              8000
            )}`,
          },
        ],
        response_format: { type: "json_object" },
        temperature: 0.7,
      });

      // Parse the OpenAI response to get quiz data
      const quizData = JSON.parse(response.choices[0].message.content);

      // Create new quiz in database
      const quiz = new Quiz({
        title: quizData.title || `Quiz from ${req.file.originalname}`,
        userId: req.userId,
        questions: quizData.questions.map((q) => ({
          questionText: q.questionText,
          questionType: q.questionType,
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
        })),
      });

      await quiz.save();

      res.status(201).send({
        id: quiz.id,
        title: quiz.title,
        questions: quiz.questions,
      });
    } catch (error) {
      console.error(error);
      res.status(500).send({ error: "Failed to generate quiz" });
    }
  }
);

// Evaluate long answer
app.post("/api/quizzes/evaluate", authenticate, async (req, res) => {
  try {
    const { questionId, answer } = req.body;

    // Find the question by ID
    const quiz = await Quiz.findOne({ "questions.id": questionId });
    if (!quiz) {
      return res.status(404).send({ error: "Question not found" });
    }

    const question = quiz.questions.find((q) => q.id === questionId);
    if (!question) {
      return res.status(404).send({ error: "Question not found" });
    }

    // Use OpenAI to evaluate the answer
    const response = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content:
            "You are an educational assistant that evaluates student answers to questions. Provide feedback and score the answer.",
        },
        {
          role: "user",
          content: `Question: ${question.questionText}\n\nCorrect Answer: ${question.correctAnswer}\n\nStudent Answer: ${answer}\n\nEvaluate if the student's answer is correct, partially correct, or incorrect. Provide constructive feedback and a score from 0.0 to 1.0.`,
        },
      ],
      response_format: { type: "json_object" },
      temperature: 0.3,
    });

    // Parse the OpenAI response to get evaluation data
    const evaluationData = JSON.parse(response.choices[0].message.content);

    res.send({
      isCorrect: evaluationData.isCorrect,
      feedback: evaluationData.feedback,
      score: evaluationData.score,
    });
  } catch (error) {
    console.error(error);
    res.status(500).send({ error: "Failed to evaluate answer" });
  }
});

// Fetch user's quizzes
app.get("/api/quizzes/user/:userId", authenticate, async (req, res) => {
  try {
    if (req.params.userId !== req.userId) {
      return res
        .status(403)
        .send({ error: "Not authorized to access these quizzes" });
    }

    const quizzes = await Quiz.find({ userId: req.params.userId });
    res.send(quizzes);
  } catch (error) {
    res.status(500).send({ error: "Server error" });
  }
});

// Start the server
const PORT = process.env.PORT || 5000;
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    // Get your actual IP address
    const networkInterfaces = require("os").networkInterfaces();
    const localIPs = Object.values(networkInterfaces)
      .flat()
      .filter((item) => !item.internal && item.family === "IPv4")
      .map((item) => item.address);

    const localIP = localIPs.length > 0 ? localIPs[0] : "localhost";

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT} on all interfaces`);
      console.log(`Server accessible at http://${localIP}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Failed to connect to MongoDB", err);
  });
